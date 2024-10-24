public with sharing class ConsolidationsHelper extends AbstractLWCHelper {

    public static final String RUN_CONSOLIDATION_ROUTINE_CUSTOM_PERMISSION_NAME = 'Run_Consolidation_Routine';

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLedgerHierarchyRecords() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            result.put('rows', LedgerHierarchy.retrieveFlat(ApiOptions.SharingContext.WITHOUT_SHARING));
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Boolean isMultiCurrencyEnabled() {
        return AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED;
    }

    @AuraEnabled
    public static Map<String, Object> saveRecord(Map<String, Object> valuesByFields, List<String> specs2Delete) {
        Set<String> uniqueSpecs2Delete = new Set<String>(specs2Delete != null ? specs2Delete : new List<String>());
        List<Map<String, Object>> errors = new List<Map<String, Object>>();
        Savepoint sp = Database.setSavepoint();
        try {
            Id ledgerId = (Id)valuesByFields.get('ledgerId');
            Id recordId = (Id)valuesByFields.get('recordId');
            Id parentId = (Id)valuesByFields.get('parentId');
            Id eliminationLedgerId;

            if (recordId == null && LedgerHandler.isConsolidationLedger(LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId))) {
                eliminationLedgerId = LedgerHandler.getInstanceWithoutSharing().getEliminationLedgersByConsolidationIds(new Set<Id> {ledgerId})[0].Id;
            }
            if (String.isBlank(ledgerId)) {
                List<Ledger_Hierarchy__c> ledgerHierarchies = DomainUtils.getLedgerHierarchiesByIds(new Set<Id>{recordId});
                if (!ledgerHierarchies.isEmpty()) {
                    ledgerId = ledgerHierarchies[0].Ledger__c;
                }
            }

            List<Ledger_Hierarchy__c> ledgerHierarchies = new List<Ledger_Hierarchy__c>{
                    new Ledger_Hierarchy__c(
                            Id = recordId,
                            Ledger__c = ledgerId,
                            Notes__c = (String)valuesByFields.get('notes')
                    )
            };
            String name = (String)valuesByFields.get('xname');
            if (String.isNotBlank(name)) {
                ledgerHierarchies[0].Name = name;
            }
            if (String.isNotBlank(parentId)) {
                ledgerHierarchies[0].Parent_Ledger_Hierarchy__c = parentId;
            }
            List<Database.UpsertResult> lhSaveResults = SFDCSecurityUtils.upsertCheckCRUDAndFLS(ledgerHierarchies, new List<String>{
                    'Ledger__c',
                    'Notes__c',
                    'Parent_Ledger_Hierarchy__c'
            }, false);
            if (lhSaveResults[0].isSuccess()) {
                Set<String> uniqueKeys = new Set<String>();
                Set<Id> ledgerIds = new Set<Id>{ledgerId};
                if (String.isNotBlank(eliminationLedgerId)) {
                    ledgerIds.add(eliminationLedgerId);
                }
                for (Id recId: ledgerIds) {
                    for (String spec : GLAccountDefaultsHandler.instance.consolidationSpecifications) {
                        uniqueKeys.add(String.join(new List<String>{ spec, recId }, ':'));
                    }
                }
                Map<String, GL_Account_Default__c> glAccountDefaultsBySpecs = glAccountDefaultsBySpecs(DomainUtils.glAccountDefaultsByUniqueKeys(uniqueKeys));

                List<GL_Account_Default__c> deleteGLAccountDefaults = new List<GL_Account_Default__c>();
                for (String spec : uniqueSpecs2Delete) {
                    if (glAccountDefaultsBySpecs.containsKey(spec)) {
                        deleteGLAccountDefaults.add(new GL_Account_Default__c(
                                Id = glAccountDefaultsBySpecs.get(String.join(new List<String>{ spec, ledgerId }, ':'))?.Id,
                                GL_Account_Specification__c = spec
                        ));
                    }
                }
                if (!deleteGLAccountDefaults.isEmpty()) {
                    List<Database.DeleteResult> deleteResults = SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteGLAccountDefaults, false);
                    for (Integer index = 0; index < deleteResults.size(); index++) {
                        if (!deleteResults[index].success) {
                            errors.add(new Map<String, Object>{
                                    'msg' => !deleteResults[index].errors.isEmpty() ? deleteResults[index].errors[0].message : null,
                                    'location' => ErrorLocation.FIELD.name(),
                                    'spec' => deleteGLAccountDefaults[index].GL_Account_Specification__c
                            });
                        }
                    }
                }

                List<GL_Account_Default__c> createGLAccountDefaults = new List<GL_Account_Default__c>();
                for (String spec : GLAccountDefaultsHandler.instance.consolidationSpecifications) {
                    if (valuesByFields.get(spec) != null && !uniqueSpecs2Delete.contains(spec)) {
                        createGLAccountDefaults.add(new GL_Account_Default__c(
                                Id = glAccountDefaultsBySpecs.get(String.join(new List<String>{ spec, ledgerId }, ':'))?.Id,
                                Ledger__c = ledgerId,
                                GL_Account_Specification__c = spec,
                                GL_Account__c = (Id)valuesByFields.get(spec)
                        ));
                        if (eliminationLedgerId != null
                                && glAccountDefaultsBySpecs.get(String.join(new List<String>{ spec, eliminationLedgerId }, ':')) == null) {
                            createGLAccountDefaults.add(new GL_Account_Default__c(
                                Ledger__c = eliminationLedgerId,
                                GL_Account_Specification__c = spec,
                                GL_Account__c = (Id)valuesByFields.get(spec)
                            ));
                        }
                    }
                }
                if (!createGLAccountDefaults.isEmpty()) {
                    List<Database.UpsertResult> defSaveResults = SFDCSecurityUtils.upsertCheckCRUDAndFLS(createGLAccountDefaults, new List<String>{
                            'Ledger__c',
                            'GL_Account_Specification__c',
                            'GL_Account__c'
                    }, false);
                    for (Integer index = 0; index < defSaveResults.size(); index++) {
                        if (!defSaveResults[index].isSuccess()) {
                            errors.add(new Map<String, Object>{
                                    'msg' => !defSaveResults[index].errors.isEmpty() ? defSaveResults[index].errors[0].message : null,
                                    'location' => ErrorLocation.FIELD.name(),
                                    'spec' => createGLAccountDefaults[index].GL_Account_Specification__c
                            });
                        }
                    }
                }
            } else {
                errors.add(new Map<String, Object>{
                        'msg' => !lhSaveResults[0].errors.isEmpty() ? lhSaveResults[0].errors[0].message : null,
                        'location' => ErrorLocation.PAGE.name()
                });
            }
        } catch (Exception e) {
            errors.add(new Map<String, Object>{
                    'msg' => e.getMessage(),
                    'location' => ErrorLocation.PAGE.name()
            });
        }

        if (!errors.isEmpty()) {
            Database.rollback(sp);
        }
        return new Map<String, Object>{'errors' => errors};
    }

    private static Map<String, GL_Account_Default__c> glAccountDefaultsBySpecs(List<GL_Account_Default__c> glAccountDefaults) {
        Map<String, GL_Account_Default__c> glAccountDefaultsBySpecs = new Map<String, GL_Account_Default__c>();
        for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
            glAccountDefaultsBySpecs.put(String.join(new List<String>{ glAccountDefault.GL_Account_Specification__c, glAccountDefault.Ledger__c }, ':'), glAccountDefault);
        }
        return glAccountDefaultsBySpecs;
    }

    @AuraEnabled
    public static Map<String, Object> fetchInitValues(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        List<Ledger_Hierarchy__c> ledgerHierarchies = DomainUtils.getLedgerHierarchiesByIds(new Set<Id>{recordId});
        if (!ledgerHierarchies.isEmpty()) {
            result.put('ledgerName', ledgerHierarchies[0].Ledger__r.Name);
            result.put('ledgerId', ledgerHierarchies[0].Ledger__c);
            result.put('xname', ledgerHierarchies[0].Name);
            result.put('notes', ledgerHierarchies[0].Notes__c);

            result.putAll(fetchGLAcctDefs(ledgerHierarchies[0].Ledger__c));
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> fetchGLAcctDefs(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        if (String.isNotBlank(recordId)) {
            Set<String> uniqueKeys = new Set<String>();
            for (String spec : GLAccountDefaultsHandler.instance.consolidationSpecifications) {
                uniqueKeys.add(String.join(new List<String>{ spec, recordId }, ':'));
            }
            List<GL_Account_Default__c> glAccountDefaults = DomainUtils.glAccountDefaultsByUniqueKeys(uniqueKeys);
            for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
                result.put(glAccountDefault.GL_Account_Specification__c, glAccountDefault.GL_Account__c);
            }
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> fetchConfigs() {
        List<GL_Account_Specification__mdt> specifications = DomainUtils.glAccountSpecifications(new Set<String>{
                GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT,
                GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT,
                GLAccountDefaultsHandler.CTA_GL_ACCOUNT
        });
        Map<String, Map<String, Object>> specificationsByDevNames = new Map<String, Map<String, Object>>();
        for (GL_Account_Specification__mdt specification : specifications) {
            specificationsByDevNames.put(specification.DeveloperName, new Map<String, Object>{
                    'devName' => specification.DeveloperName,
                    'label' => specification.Label,
                    'helpText' => specification.Help_Text__c,
                    'isRequired' => specification.Required__c
                            || (specification.DeveloperName == GLAccountDefaultsHandler.CTA_GL_ACCOUNT && AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED)
            });
        }

        return new Map<String, Object>{
                'specificationsByDevNames' => specificationsByDevNames,
                'isMultiCurrencyEnabled' => AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED
        };
    }

    @AuraEnabled
    public static Accounting_Period__c getLastPeriodClosed() {
        Accounting_Period__c result;
        try {
            AccountingPeriodHandler aph = AccountingPeriodHandler.getInstance();
            result = aph.getLastClosedOrArchivedAccountingPeriod();
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Accounting_Period__c getFirstPeriodOpen() {
        Accounting_Period__c result;
        try {
            AccountingPeriodHandler aph = AccountingPeriodHandler.getInstance();
            result = aph.getFirstPeriodWithStatusOpen();
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse saveLedgerHierarchySortOrders(List<Ledger_Hierarchy__c> ledgerHierarchies) {
        SaveResponse result = new SaveResponse();
        try {
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Ledger_Hierarchy__c.Sort_Order__c});
            LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
            SFDCSecurityUtils.updateProxy(ledgerHierarchies);
            LedgerHierarchyActions.bypassConsolidationRoutineValidation = false;
            TriggerObserver.reset();
            result.isSuccess = true;
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse runConsolidation(Id parentLedgerHierarchyId, Id periodId, Boolean runWithChildren) {
        SaveResponse response;
        try {
            response = new SaveResponse(LedgerHierarchy.consolidate(parentLedgerHierarchyId, runWithChildren, periodId));
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static Boolean isRunConsolidationRoutineAccessAllowed() {
        return FeatureManagement.checkPermission(RUN_CONSOLIDATION_ROUTINE_CUSTOM_PERMISSION_NAME);
    }

    public enum ErrorLocation {
        PAGE, FIELD
    }
}