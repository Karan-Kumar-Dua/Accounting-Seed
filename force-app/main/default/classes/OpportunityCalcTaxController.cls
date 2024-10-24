public with sharing class OpportunityCalcTaxController extends AbstractLWCHelper {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String TAX_TYPE_TAX_PRODUCT = NativeTaxLineLevel.TAX_TYPE_TAX_PRODUCT;

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> retrieveLines(Id opportunityId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            List<Opportunity> opportunities = opportunitiesByIds(new Set<Id>{opportunityId});
            List<Account_Tax__c> accountTaxes = !opportunities.isEmpty() && String.isNotBlank(opportunities[0].AccountId) ?
                accountTaxesByAccountIds(new Set<Id>{opportunities[0].AccountId}) : new List<Account_Tax__c>();
            List<Product2> product2s = new List<Product2>();
            for (Account_Tax__c accountTax : accountTaxes) {
                if (accountTax.Tax_Rate__r != null) {
                    product2s.add(accountTax.Tax_Rate__r);
                }
            }
            List<Tax_Settings__c> taxSettings = queryTaxSettings();
            for (Tax_Settings__c taxSetting : taxSettings) {
                if (taxSetting.Sales_Tax_Product__r != null) {
                    product2s.add(taxSetting.Sales_Tax_Product__r);
                }
            }

            Map<Id, Product2> prodMap = new Map<Id, Product2>();
            prodMap.putAll(product2s);

            result.putAll(new Map<String, Object>{
                    'taxProductLines' => opportunityLinesByOpportunityIds(new Set<Id>{opportunityId}),
                    'taxRateProductsByIds' => prodMap
            });
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> calcTax(Map<String, Object> params, Map<Id, Map<String, Object>> previewParamsByIds) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            Id opportunityId = (Id) params?.get('opportunityId');
            Id ledgerId = (Id) params?.get('ledgerId');
            NativeTaxLineLevel.doCommit = true;
            AvaTaxLineLevel.doCommit = true;
            List<TaxServiceResult> taxServiceResults = TaxService.calcTaxes(
                    new Map<SObject, Id>{new Opportunity(Id = opportunityId) => ledgerId},
                    previewParamsByIds
            );
            if (!taxServiceResults.isEmpty()) {
                TaxServiceResult serviceResult = taxServiceResults[0];
                TaxServiceResult.TaxServiceResultLine sourceDoc = !serviceResult.sourceDocs.isEmpty() ?
                        serviceResult.sourceDocs[0] : null;
                AvaTaxHelper.AvaTaxCalculationReport report =
                        serviceResult.avaTaxCalcResult?.reportMap?.get((Id)sourceDoc?.sourceObj.get('Id'));
                if (serviceResult.isSuccess) {
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceDoc.sourceObj, new List<String>{
                            PACKAGE_QUALIFIER + 'Tax_Amount__c'
                    });

                    List<OpportunityLineItem> lines = new List<OpportunityLineItem>();
                    for (SObject sourceObjLine : report != null ? report.lines : sourceDoc.sourceObjLines) {
                        OpportunityLineItem line = new OpportunityLineItem(
                                Id = (Id)sourceObjLine.get('Id'),
                                Tax_Amount__c = (Decimal)sourceObjLine.get(PACKAGE_QUALIFIER + 'Tax_Amount__c')
                        );
                        if (sourceObjLine.getPopulatedFieldsAsMap().containsKey(PACKAGE_QUALIFIER + 'Tax_Group__c')) {
                            line.Tax_Group__c = (Id) sourceObjLine.get(PACKAGE_QUALIFIER + 'Tax_Group__c');
                        }
                        if (TaxService.previewParamsByIds != null && TaxService.previewParamsByIds.get((Id)sourceObjLine.get('Id')) != null &&
                                TaxService.previewParamsByIds.get((Id)sourceObjLine.get('Id')).get('taxSettingCombinedRate') != null) {
                            line.put(PACKAGE_QUALIFIER + 'Tax_Group__c', TaxService.previewParamsByIds.get((Id)sourceObjLine.get('Id')).get('taxSettingId'));
                        }
                        lines.add(line);
                    }
                    if (!lines.isEmpty()) {
                        SFDCSecurityUtils.updateCheckCRUDAndFLS(lines, new List<String>{
                                PACKAGE_QUALIFIER + 'Tax_Amount__c',
                                PACKAGE_QUALIFIER + 'Tax_Group__c'
                        });
                    }
                } else if (sourceDoc != null) {
                    List<Map<String, Object>> errors = new List<Map<String, Object>>();
                    if (report != null) {
                        errors.add(new Map<String, Object>{
                                'code' => report.error.code.name(),
                                'message' => report.error.errorMsg
                        });
                    }
                    for (TaxServiceResult.TaxServiceResultLineErrorItem error : sourceDoc.errors.items) {
                        errors.add(new Map<String, Object>{
                                'code' => error.code,
                                'message' => error.message
                        });
                    }

                    result = new Map<String, Object>{
                            'errors' => errors
                    };
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> retrieveHeaderData(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            List<Opportunity> opportunities = opportunitiesByIds(new Set<Id>{recordId});

            result = new Map<String, Object>{
                    'isHeaderLevelPost' => AccountingSettingsHandler.isHeaderLevelPost(),
                    'ledgerId' => LedgerHandler.getLedgerId(),
                    'record' => new Map<String, Object>{
                            'name' => opportunities[0].Name,
                            'id' => opportunities[0].Id,
                            'currencyIsoCode' => MultiCurrencyHandler.isMultiCurrencyEnabled ?
                                    opportunities[0].get('CurrencyIsoCode') : null,
                            'url' => String.isNotBlank(opportunities[0].Id) ?
                                '/' + opportunities[0].Id : null
                    },
                    'customer' => new Map<String, Object>{
                            'name' => opportunities[0].Account.Name,
                            'id' => opportunities[0].Account.Id,
                            'url' => String.isNotBlank(opportunities[0].Account.Id) ?
                                '/' + opportunities[0].Account.Id : null
                    }
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static Map<String, Object> retrieveData(Map<String, Object> params, Map<Id, Map<String, Object>> previewParamsByIds) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            Id opportunityId = (Id) params?.get('opportunityId');
            Id ledgerId = (Id) params?.get('ledgerId');
            NativeTaxLineLevel.doCommit = false;
            AvaTaxLineLevel.doCommit = false;
            List<TaxServiceResult> taxServiceResults = TaxService.calcTaxes(
                    new Map<SObject, Id>{new Opportunity(Id = opportunityId) => ledgerId},
                    previewParamsByIds
            );

            if (!taxServiceResults.isEmpty()) {
                TaxServiceResult serviceResult = taxServiceResults[0];
                List<Map<String, Object>> sourceDocs = new List<Map<String, Object>>();
                for (TaxServiceResult.TaxServiceResultLine sourceDoc : serviceResult.sourceDocs) {
                    AvaTaxHelper.AvaTaxCalculationReport report =
                            serviceResult.avaTaxCalcResult?.reportMap?.get((Id)sourceDoc?.sourceObj?.get('Id'));

                    List<Map<String, Object>> errors = new List<Map<String, Object>>();
                    if (report != null && report.error != null) {
                        errors.add(new Map<String, Object>{
                                'code' => report.error.code?.name(),
                                'message' => report.error.errorMsg
                        });
                    }
                    for (TaxServiceResult.TaxServiceResultLineErrorItem error : sourceDoc.errors.items) {
                        errors.add(new Map<String, Object>{
                                'code' => error.code,
                                'message' => error.message
                        });
                    }

                    sourceDocs.add(new Map<String, Object>{
                            'isSuccess' => sourceDoc.isSuccess,
                            'errors' => errors,
                            'sourceObj' => sourceDoc.sourceObj,
                            'sourceObjLines' => report != null ? report.lines : sourceDoc.sourceObjLines
                    });
                }

                result = new Map<String, Object>{
                        'isShowDiscount' => isShowDiscount(serviceResult),
                        'taxServiceResult' => new Map<String, Object>{
                                'isSuccess' => serviceResult.isSuccess,
                                'sourceDocs' => sourceDocs
                        }
                };
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    private static List<Account_Tax__c> accountTaxesByAccountIds(Set<Id> accountIds) {
        List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Tax_Rate__r.Tax_Rate__c',
                'Tax_Rate__r.Id',
                'Tax_Rate__r.Name'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        List<String> APPLICABLE_TYPES_OF_TAXES = NativeTaxLineLevel.APPLICABLE_TYPES_OF_TAXES_BY_TYPES.get(Opportunity.getSObjectType());
        String queryCondition = 'Account__c IN :accountIds AND Tax_Type__c =: APPLICABLE_TYPES_OF_TAXES';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Tax__c.SObjectType);
        theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<Account_Tax__c>) Database.query(theQuery.toSOQL());
    }

    private static List<Tax_Settings__c> queryTaxSettings() {
        List<String> queryFields = new List<String>{
                'Id',
                'Sales_Tax_Product__r.Id',
                'Sales_Tax_Product__r.Name'
        };

        SOQLBuilder theQuery = new SOQLBuilder(Tax_Settings__c.SObjectType);
        theQuery.selectFields(queryFields);

        return (List<Tax_Settings__c>) Database.query(theQuery.toSOQL());
    }

    private static List<OpportunityLineItem> opportunityLinesByOpportunityIds(Set<Id> opportunityIds) {
        List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Subtotal',
                'Product2Id',
                'Product2.Name',
                'Product2.Accounting_Type__c',
                'Product2.Tax_Rate__c',
                'PricebookEntryId'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        if (DomainUtils.isDiscountIncludedInOpportunityLineItems(opportunityIds)) {
            queryFields.add('Discount');
        }

        String queryCondition = 'OpportunityId IN :opportunityIds AND Product2.Accounting_Type__c =: TAX_TYPE_TAX_PRODUCT';

        SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
        theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
    }

    private static List<Opportunity> opportunitiesByIds(Set<Id> ids) {
        List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Account.Id',
                'Account.Name'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<Opportunity>) Database.query(theQuery.toSOQL());
    }

    private static Boolean isShowDiscount(TaxServiceResult serviceResult) {
        Boolean result = false;
        List<SObject> lines = serviceResult != null && serviceResult.sourceDocs != null && !serviceResult.sourceDocs.isEmpty() &&
                serviceResult.sourceDocs[0] != null ? serviceResult.sourceDocs[0].sourceObjLines : null;
        if (lines != null && !lines.isEmpty()) {
            for (SObject oppLineItem : lines) {
                if (oppLineItem.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                    result = true;
                }
            }
        }
        return result;
    }
}