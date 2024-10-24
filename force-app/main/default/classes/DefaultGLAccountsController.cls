public with sharing class DefaultGLAccountsController {

    public static Set<String> erpAverageCostRequiredSpecifications = new Set<String>{
        GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT,
        GLAccountDefaultsHandler.WORK_IN_PROCESS_GL_ACCOUNT
    };

    public static Set<String> erpStandardCostRequiredSpecifications = new Set<String>{
        GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT
    };

    @AuraEnabled
    public static Map<String, Object> initialGLAccountDefsCreating() {
        GLAccountDefaultsHandler.instance.setExistedGLAccountsFromSettings();
        GLAccountDefaultActions.isPreventUpdateOverride = true;
        return new Map<String, Object>{
            'results' => GLAccount.createGLAccountDefaultsByLedger(LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().keySet())
        };
    }

    @AuraEnabled(cacheable=true)
    public static Id getLedgerId() {
        return LedgerHandler.getLedgerIdWithSharing();
    }

    @AuraEnabled
    public static Map<String, Object> saveDetails(List<Map<String, Object>> data, Id ledgerId) {

        Set<String> uniqueKeys = new Set<String>();
        for (Map<String, Object> dataItem : data) {
            uniqueKeys.add((String) dataItem.get('uniqueKey'));
        }

        Map<String, GL_Account_Default__c> glAccountDefaultsByUniqueKeys = new Map<String, GL_Account_Default__c>();
        for (GL_Account_Default__c glAccountDefault : DomainUtils.glAccountDefaultsByUniqueKeys(uniqueKeys)) {
            glAccountDefaultsByUniqueKeys.put(glAccountDefault.Unique_Key__c, glAccountDefault);
        }

        List<Map<String, Object>> wrapsUpsert = new List<Map<String, Object>>();
        List<GL_Account_Default__c> records4Upsert = new List<GL_Account_Default__c>();
        Set<String> specDevNames = new Set<String>();

        List<Map<String, Object>> wrapsDelete = new List<Map<String, Object>>();
        List<GL_Account_Default__c> records4Delete = new List<GL_Account_Default__c>();
        Boolean isAccountingSettingChanged = false;
        for (Map<String, Object> dataItem : data) {
            String glAccountId = (String) dataItem.get('glAccountId');
            GL_Account_Default__c glAccountDefault = glAccountDefaultsByUniqueKeys.get((String) dataItem.get('uniqueKey'));
            String specDevName = (String) dataItem.get('specDevName');
            specDevNames.add(specDevName);

            if (specDevName != GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT) {
                if (String.isNotBlank(glAccountId)) {
                    records4Upsert.add(new GL_Account_Default__c(
                        Id = glAccountDefault != null ? glAccountDefault.Id : null,
                        GL_Account__c = glAccountId,
                        Ledger__c = ledgerId,
                        GL_Account_Specification__c = specDevName
                    ));
                    wrapsUpsert.add(dataItem);
                } else if (String.isBlank(glAccountId) && glAccountDefault != null) {
                    records4Delete.add(new GL_Account_Default__c(
                        Id = glAccountDefault.Id
                    ));
                    wrapsDelete.add(dataItem);
                }
            } else {
                Accounting_Settings__c accountingSettings = AccountingSettingsHandler.getAccountingSettings();
                accountingSettings.Default_Project_Task_Labor_GL_Account__c = glAccountId;
                isAccountingSettingChanged = true;
            }
        }

        Savepoint sPoint = Database.setSavepoint();
        List<Map<String, Object>> errors = new List<Map<String, Object>>();
        if (!records4Delete.isEmpty()) {
            try {
                SFDCSecurityUtils.deleteProxyDatabase(records4Delete, true);
            } catch (DmlException e) {
                for (Integer index = 0; index < e.getNumDml(); index++) {
                    Integer recordIndex = e.getDmlIndex(index);
                    errors.add(new Map<String, Object>{
                        'specDevName' => (String) wrapsDelete[recordIndex].get('specDevName'),
                        'message' => e.getDmlMessage(index)
                    });
                }
            }
        }
        if (!records4Upsert.isEmpty()) {
            try {
                SFDCSecurityUtils.upsertProxy(records4Upsert, true);
            } catch (DmlException e) {
                for (Integer index = 0; index < e.getNumDml(); index++) {
                    Integer recordIndex = e.getDmlIndex(index);
                    errors.add(new Map<String, Object>{
                        'specDevName' => (String) wrapsUpsert[recordIndex].get('specDevName'),
                        'message' => e.getDmlMessage(index)
                    });
                }
            }
        }
        if (isAccountingSettingChanged) {
            try {
                SFDCSecurityUtils.updateProxy(new List<Accounting_Settings__c>{
                    AccountingSettingsHandler.getAccountingSettings()
                }, true);
            } catch (DmlException e) {
                errors.add(new Map<String, Object>{
                    'specDevName' => GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT,
                    'message' => e.getDmlMessage(0)
                });
            }
        }

        Map<String, Object> result = new Map<String, Object>{
                'defaultWraps' => fetchDetails(ledgerId),
                'errors' => errors
        };
        if (errors.isEmpty()) {
            try {
                // When a user makes a change to their (primary) accrual ledger on the Default GL Accounts page,
                // automatically update the related (shadow) cash ledger with these same changes.
                String shadowLedgerId;
                Map<String, Object> shadowDetails;
                if (!records4Upsert.isEmpty() || !records4Delete.isEmpty()) {
                    shadowLedgerId = syncDefaultGlAccountsForShadowLedger(ledgerId, specDevNames);
                    if (String.isNotBlank(shadowLedgerId)) {
                        GLAccountDefaultsHandler.instance = null;
                        shadowDetails = fetchDetails(shadowLedgerId);
                    }
                }

                result.put('shadowLedgerId', shadowLedgerId);
                result.put('shadowWraps', shadowDetails);
            } catch (Exception ex) {}
        }

        if (!errors.isEmpty()) {
            Database.rollback(sPoint);
        }

        return result;
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> fetchDetails(Id ledgerId) {
        List<GL_Account_Specification__mdt> glAccountSpecifications = DomainUtils.allGLAccountSpecifications();
        return prepareDefaultWraps(GLAccountDefaultsHandler.instance.glAccountDefaultsByLedgerId(ledgerId), glAccountSpecifications);
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> fetchSettings() {
        List<Map<String, Object>> ledgerOptions = new List<Map<String, Object>>();
        List<Ledger__c> ledgers = queryLedgers();
        Ledger__c olderLedger = null;
        for (Ledger__c ledger : ledgers) {
            if (olderLedger == null || ledger.CreatedDate < olderLedger.CreatedDate) {
                olderLedger = ledger;
            }
        }
        List<GL_Account_Specification__mdt> glAccountSpecifications = DomainUtils.allGLAccountSpecifications();
        Map<Id, Map<String, Object>> defaultWrapsByLedgerIds = new Map<Id, Map<String, Object>>();
        Boolean isGLDefaultRecordsExist = false;
        for (Ledger__c ledger : ledgers) {
            List<GLAccountDefault> glAccountDefaults = GLAccountDefaultsHandler.instance.glAccountDefaultsByLedgerId(ledger.Id);

            ledgerOptions.add(new Map<String, Object>{
                'isDefault' => ledger.Id == olderLedger.Id,
                'label' => ledger.Name,
                'value' => ledger.Id,
                'description' => ledger.Type__c,
                'isGLDefaultRecordsExist' => glAccountDefaults != null && !glAccountDefaults.isEmpty(),
                'isPrimary' => LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(ledger.Id) && !ledger.Is_Shadow__c
            });

            defaultWrapsByLedgerIds.put(
                ledger.Id,
                prepareDefaultWraps(glAccountDefaults, glAccountSpecifications)
            );

            if (glAccountDefaults != null && !glAccountDefaults.isEmpty()) {
                isGLDefaultRecordsExist = true;
            }
        }

        Map<String, List<Map<String, Object>>> specWrapsByTypes = new Map<String, List<Map<String, Object>>>();
        for (GL_Account_Specification__mdt specification : glAccountSpecifications) {
            if (specWrapsByTypes.get(specification.Type__c) == null) {
                specWrapsByTypes.put(specification.Type__c, new List<Map<String, Object>>());
            }
            specWrapsByTypes.get(specification.Type__c).add(new Map<String, Object>{
                'label' => specification.Label,
                'devName' => specification.DeveloperName,
                'required' => getRequired(specification),
                'helpText' => specification.Help_Text__c,
                'type' => specification.Type__c
            });
        }

        return new Map<String, Object>{
            'ledgerOptions' => ledgerOptions,
            'defaultWrapsByLedgerIds' => defaultWrapsByLedgerIds,
            'specWrapsByTypes' => specWrapsByTypes,
            'enablements' => new Map<String, Boolean>{
                'multiCurrencyEnabled' => MultiCurrencyHandler.isMultiCurrencyEnabled
            },
            'isGLDefaultRecordsExist' => isGLDefaultRecordsExist
        };
    }

    private static Boolean getRequired(GL_Account_Specification__mdt spec) {
        Boolean result = spec.Required__c;
        if (AccountingSettingsHandler.isERPEnabled()
            && AccountingSettingsHandler.isInventoryValuationAverageCost()
            && erpAverageCostRequiredSpecifications.contains(spec.DeveloperName)) {

            result = true;
        }

        if (AccountingSettingsHandler.isERPEnabled()
            && AccountingSettingsHandler.isInventoryValuationStandardCost()
            && (erpAverageCostRequiredSpecifications.contains(spec.DeveloperName) || erpStandardCostRequiredSpecifications.contains(spec.DeveloperName))) {

            result = true;
        }

        return result;
    }

    private static Map<String, Map<String, Object>> prepareDefaultWraps(
        List<GLAccountDefault> glAccountDefaults,
        List<GL_Account_Specification__mdt> glAccountSpecifications
    ) {

        glAccountDefaults = glAccountDefaults != null ? glAccountDefaults : new List<GLAccountDefault>();

        Map<String, Map<String, Object>> defaultWraps = new Map<String, Map<String, Object>>();
        for (GLAccountDefault defaultItem : glAccountDefaults) {
            defaultWraps.put(defaultItem.glAccountSpecification.DeveloperName, new Map<String, Object>{
                'glAccountId' => defaultItem.glAccount.Id,
                'specDevName' => defaultItem.glAccountSpecification.DeveloperName
            });
        }
        for (GL_Account_Specification__mdt specification : glAccountSpecifications) {
            if (!defaultWraps.containsKey(specification.DeveloperName)) {
                defaultWraps.put(specification.DeveloperName, new Map<String, Object>{
                    'specDevName' => specification.DeveloperName
                });
            }
            if (specification.DeveloperName == GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT) {
                defaultWraps.put(specification.DeveloperName, new Map<String, Object>{
                    'specDevName' => specification.DeveloperName,
                    'glAccountId' => AccountingSettingsHandler.getAccountingSettings().Default_Project_Task_Labor_GL_Account__c
                });
            }
        }
        return defaultWraps;
    }

    private static List<Ledger__c> queryLedgers() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'CreatedDate',
            GlobalVariables.PACKAGE_QUALIFIER + 'Type__c',
            GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Method__c',
            GlobalVariables.PACKAGE_QUALIFIER + 'Related_Ledger__c',
            GlobalVariables.PACKAGE_QUALIFIER + 'Is_Shadow__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        Set<String> types = new Set<String>{
            LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_BUDGET
        };
        SOQLBuilder theQuery = new SOQLBuilder(Ledger__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(GlobalVariables.PACKAGE_QUALIFIER + 'Type__c =: types AND ' + GlobalVariables.PACKAGE_QUALIFIER + 'Active__c = TRUE')
            .addOrdering(Ledger__c.Name, SOQLBuilder.SortOrder.ASCENDING)
            .setLimit(50000);

        return (List<Ledger__c>) Database.query(theQuery.toSOQL());
    }

    private static String syncDefaultGlAccountsForShadowLedger(Id primaryLedgerId, Set<String> specsToReplace) {
        String result;
        //Validate the ledger is primary,
        //i.e. Accounting Method is equal to "Accrual and Cash" and the field Related Ledger is not empty
        Ledger__c primaryLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(primaryLedgerId);
        if (LedgerHandler.getLedgerAccountingMethod(primaryLedgerId) == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
                && primaryLedger.Related_Ledger__c != null) {

            //Get Shadow Ledger
            Ledger__c shadowLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(primaryLedger.Related_Ledger__c);
            //delete Default GL Accounts for shadow ledger with certain GL Account Specifications
            Set<String> keys = new Set<String>();
            //build keys to query Default GL Accounts
            for (String specName : specsToReplace) {
                keys.add(specName + ':' + shadowLedger.Id);
            }
            //query Default GL Accounts
            List<GL_Account_Default__c> glAccountsDefaultToDelete = DomainUtils.glAccountDefaultsByUniqueKeys(keys);
            //delete from DB
            SFDCSecurityUtils.deleteProxy(glAccountsDefaultToDelete);
            //query Default GL Accounts for primary ledger
            keys = new Set<String>();
            for (String specName : specsToReplace) {
                keys.add(specName + ':' + primaryLedger.Id);
            }
            List<GL_Account_Default__c> glAccountsDefaultToCopy = new List<GL_Account_Default__c>();
            for (GL_Account_Default__c gld : DomainUtils.glAccountDefaultsByUniqueKeys(keys))  {
                GL_Account_Default__c tempGLD = gld.clone(false, false, false, false);
                tempGLD.Unique_Key__c = null;
                tempGLD.Ledger__c = shadowLedger.Id;
                glAccountsDefaultToCopy.add(tempGLD);
            }
            //insert new Default GL Accounts for Shadow Ledger
            GLAccountDefaultActions.isPreventUpdateOverride = true;
            SFDCSecurityUtils.insertProxy(glAccountsDefaultToCopy);
            GLAccountDefaultActions.isPreventUpdateOverride = false;

//            result = fetchDetails(shadowLedger.Id);
//            result.put('shadowLedgerId', String.valueOf(shadowLedger.Id));
            result = shadowLedger.Id;
        }
        return result;
    }

}