public with sharing class BDCBankRulesHelper extends AbstractLWCHelper {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestVisible
    private static final Map<String,Map<String,List<String>>> actionFieldOptions = new Map<String,Map<String,List<String>>> {
        'Cash_In' => new Map<String,List<String>> {
            PACKAGE_QUALIFIER + 'Journal_Entry_Line__c' => new List<String> {
                PACKAGE_QUALIFIER + 'Account__c',
                PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
                PACKAGE_QUALIFIER + 'GL_Account__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
                PACKAGE_QUALIFIER + 'Product__c',
                PACKAGE_QUALIFIER + 'Project__c',
                PACKAGE_QUALIFIER + 'Project_Task__c',
                PACKAGE_QUALIFIER + 'Description__c'
            },
            PACKAGE_QUALIFIER + 'Cash_Receipt__c' => new List<String> {
                PACKAGE_QUALIFIER + 'Account__c',
                PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
                PACKAGE_QUALIFIER + 'Credit_GL_Account__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
                PACKAGE_QUALIFIER + 'Product__c',
                PACKAGE_QUALIFIER + 'Project__c',
                PACKAGE_QUALIFIER + 'Project_Task__c',
                PACKAGE_QUALIFIER + 'Description__c'
            }
        },
        'Cash_Out' => new Map<String,List<String>> {
            PACKAGE_QUALIFIER + 'Journal_Entry_Line__c' => new List<String> {
                PACKAGE_QUALIFIER + 'Account__c',
                PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
                PACKAGE_QUALIFIER + 'GL_Account__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
                PACKAGE_QUALIFIER + 'Product__c',
                PACKAGE_QUALIFIER + 'Project__c',
                PACKAGE_QUALIFIER + 'Project_Task__c',
                PACKAGE_QUALIFIER + 'Description__c'
            },
            PACKAGE_QUALIFIER + 'Cash_Disbursement__c' => new List<String> {
                PACKAGE_QUALIFIER + 'Vendor__c',
                PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
                PACKAGE_QUALIFIER + 'Debit_GL_Account__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
                PACKAGE_QUALIFIER + 'Product__c',
                PACKAGE_QUALIFIER + 'Project__c',
                PACKAGE_QUALIFIER + 'Project_Task__c',
                PACKAGE_QUALIFIER + 'Description__c'
            }
        },
        'Transfer' => new Map<String,List<String>> {
            PACKAGE_QUALIFIER + 'Journal_Entry_Line__c' => new List<String> {}
        }
    };

    @TestVisible
    private static final String FIA_REQUIRED = Label.ERR_FIA_REQUIRED;
    @TestVisible
    private static final String CONDITION_REQUIRED = Label.COMMON_ONE_CONDITION_REQUIRED;
    @TestVisible
    private static final String CONDITION_FIELDS_REQUIRED = Label.COMMON_ALL_CONDITION_FIELDS_REQUIRED;
    @TestVisible
    private static final String ACTION_REQUIRED = Label.COMMON_ONE_ACTION_REQUIRED;
    @TestVisible
    private static final String ACTION_FIELDS_REQUIRED = Label.COMMON_ALL_ACTION_FIELDS_REQUIRED;

    public class BankRule {
        @AuraEnabled
        public Bank_Rule__c rule;
        @AuraEnabled
        public List<Id> glams;
        @AuraEnabled
        public List<Bank_Rule_Condition__c> conditions;
        @AuraEnabled
        public List<Bank_Rule_Action__c> actions;

        public BankRule(Bank_Rule__c rule, 
                List<Id> glams,
                List<Bank_Rule_Condition__c> conditions, 
                List<Bank_Rule_Action__c> actions) {
            this.rule = rule;
            this.glams = glams;
            this.conditions = conditions;
            this.actions = actions;
        }
    }

    @AuraEnabled
    public static List<Bank_Rule__c> getBankRules(String type) {
        try {
            List<String> queryFields = new List<String> {
                'Id',
                'Name',
                'Active__c',
                'Priority__c',
                'Type__c',
                'Evaluation_Type__c',
                'Source_Record_Type__c',
                'Description__c'
            };
            String queryCondition = 'Type__c = :type';
    
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Bank_Rule__c', 'Priority__c', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder ruleQuery = new SOQLBuilder(Bank_Rule__c.SObjectType);
            ruleQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(Limits.getLimitDMLRows())
                .addOrdering(ordering);

            return (List<Bank_Rule__c>) Database.query(ruleQuery.toSOQL());
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
    }

    @AuraEnabled
    public static BankRule getBankRule(Id ruleId) {
        try {
            Bank_Rule__c rule = getRule(ruleId);
            List<Id> glams = new List<Id>();
            for(Bank_Rule_GLAM__c glam : getRuleGLAMs(ruleId)) {
                glams.add(glam.GL_Account_Mapping__c);
            }
            List<Bank_Rule_Condition__c> conditions = getRuleConditions(ruleId);
            List<Bank_Rule_Action__c> actions = getRuleActions(ruleId);
            return new BankRule(rule, glams, conditions, actions);
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<CustomSelectOption> getActionFields(String ruleType, String sourceDocType) {
        List<CustomSelectOption> opts = new List<CustomSelectOption>();

        try {
            Boolean cashFlowEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
            
            List<String> fieldWhitelist = actionFieldOptions.get(ruleType).get(sourceDocType);
            if (!cashFlowEnabled) {
                fieldWhitelist.remove(fieldWhitelist.indexOf(PACKAGE_QUALIFIER + 'Cash_Flow_Category__c'));
            }

            Map<String,Schema.SObjectField> sObjectFields = 
                Schema.describeSObjects(new List<String>{ sourceDocType }).get(0).fields.getMap();
            
            Schema.SObjectField sObjectField;
            Schema.DescribeFieldResult description;
            for (String fieldName : fieldWhitelist) {
                sObjectField = sObjectFields.get(fieldName);
                if (sObjectField != null) {
                    description = sObjectField.getDescribe();
                    if (description.isAccessible()) {
                        opts.add(new CustomSelectOption(description.getName(), description.getLabel()));
                    }
                }
            }

            opts.sort();
        } catch(Exception ex) {}

        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<CustomSelectOption> getFinancialInstitutionAccountOptions() {
        List<CustomSelectOption> opts = new List<CustomSelectOption>();

        try {
            List<String> fields = new List<String> {
                'Id',
                'Account_Name__c'
            };
    
            String condition = 'Inactive__c = FALSE';
            
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('GL_Account_Mapping__c', 'Account_Name__c', SOQLBuilder.SortOrder.ASCENDING);
            
            SOQLBuilder queryBuilder = new SOQLBuilder(GL_Account_Mapping__c.SObjectType);
            queryBuilder
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(fields)
                .setCondition(condition)
                .setLimit(Limits.getLimitDMLRows())
                .addOrdering(ordering);

            List<GL_Account_Mapping__c> glams = (List<GL_Account_Mapping__c>) Database.query(queryBuilder.toSOQL());
            for(GL_Account_Mapping__c glam : glams) {
                opts.add(new CustomSelectOption(glam.Id, glam.Account_Name__c));
            }
        } catch(Exception ex) {}

        return opts;
    }

    @AuraEnabled
    public static void saveBankRule(
            Bank_Rule__c rule, 
            List<Id> glams,
            List<Bank_Rule_Condition__c> conditions,
            List<Bank_Rule_Action__c> actions,
            List<Bank_Rule_Condition__c> deleteConditions, 
            List<Bank_Rule_Action__c> deleteActions) {

        Savepoint sp = Database.setSavepoint();

        try {
            SFDCSecurityUtils.upsertCheckCRUDAndFLS(rule, new List<String> {
                'Name',
                'Active__c',
                'Priority__c',
                'Type__c',
                'Evaluation_Type__c',
                'Source_Record_Type__c',
                'Description__c',
                'Apply_To_All_Financial_Accounts__c'
            });

            if (!rule.Apply_To_All_Financial_Accounts__c && (glams == null || glams.isEmpty())) {
                throw buildException(ExceptionCode.VALIDATION, FIA_REQUIRED);
            }
            saveBankRuleGLAMs(rule.Id, glams);

            if (deleteConditions != null && deleteConditions.size() > 0) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteConditions);
            }              
            saveConditions(conditions, rule.ID);

            if (deleteActions != null && deleteActions.size() > 0) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteActions);
            }
            saveActions(actions, rule.ID);

        } catch (AuraHandledException ex) {
            Database.rollback(sp);
            throw ex;
        } catch (SFDCSecurityUtils.SecurityException ex) {
            Database.rollback(sp);
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        } catch (DMLException ex) {
            Database.rollback(sp);
            throw buildException(ExceptionCode.VALIDATION, ex.getDmlMessage(0));
        } catch (Exception ex) {
            Database.rollback(sp);
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
    }

    private static void populateMasterDetail(List<SObject> objs, ID masterID) {
        for (SObject obj : objs) {
            if (obj.get('ID') == null) {
                obj.put('Bank_Rule__c', masterID);
            }
        }
    }

    private static void saveActions(List<Bank_Rule_Action__c> actions, Id ruleId) {
        if (actions == null || actions.isEmpty()) {
            throw buildException(ExceptionCode.VALIDATION, ACTION_REQUIRED);
        }

        populateMasterDetail(actions, ruleId);

        List<Bank_Rule_Action__c> inserts = new List<Bank_Rule_Action__c>();
        List<Bank_Rule_Action__c> updates = new List<Bank_Rule_Action__c>();
        for (Bank_Rule_Action__c action : actions) {
            if (action.get('ID') == null) {
                inserts.add(action);
            } else {
                updates.add(action);
            }
        }

        try {
            if (!updates.isEmpty()) {
                SFDCSecurityUtils.updateCheckCRUDAndFLS(updates, new List<String> {
                    'Target_Field__c',
                    'Value__c'
                });
            }
            if (!inserts.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(inserts, new List<String> {
                    'Bank_Rule__c',
                    'Target_Field__c',
                    'Value__c'
                });
            }
        } catch(DMLException ex) {
            if (ex.getDmlType(0) == StatusCode.REQUIRED_FIELD_MISSING) {
                throw buildException(ExceptionCode.VALIDATION, ACTION_FIELDS_REQUIRED);
            }
            throw ex;
        }
    }

    private static void saveConditions(List<Bank_Rule_Condition__c> conditions, Id ruleId) {
        if (conditions == null || conditions.isEmpty()) {
            throw buildException(ExceptionCode.VALIDATION, CONDITION_REQUIRED);
        }

        populateMasterDetail(conditions, ruleId);

        List<Bank_Rule_Condition__c> inserts = new List<Bank_Rule_Condition__c>();
        List<Bank_Rule_Condition__c> updates = new List<Bank_Rule_Condition__c>();
        for (Bank_Rule_Condition__c condition : conditions) {
            if (condition.get('ID') == null) {
                inserts.add(condition);
            } else {
                updates.add(condition);
            }
        }

        try {
            if (!updates.isEmpty()) {
                SFDCSecurityUtils.updateCheckCRUDAndFLS(updates, new List<String> {
                    'Target_Field__c',
                    'Operator__c',
                    'Amount__c',
                    'Description__c',
                    'High_Level_Category__c',
                    'Category__c',
                    'Detail_Category__c',
                    'Base_Type__c',
                    'Type__c'
                });
            }
            if (!inserts.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(inserts, new List<String> {
                    'Bank_Rule__c',
                    'Target_Field__c',
                    'Operator__c',
                    'Amount__c',
                    'Description__c',
                    'High_Level_Category__c',
                    'Category__c',
                    'Detail_Category__c',
                    'Base_Type__c',
                    'Type__c'
                });
            }
        } catch(DMLException ex) {
            if (ex.getDmlType(0) == StatusCode.REQUIRED_FIELD_MISSING) {
                throw buildException(ExceptionCode.VALIDATION, CONDITION_FIELDS_REQUIRED);
            }
            throw ex;
        }
    }

    private static void saveBankRuleGLAMs(Id ruleId, List<Id> glams) {
        List<Bank_Rule_GLAM__c> insertBankRuleGLAMs = new List<Bank_Rule_GLAM__c>();
        List<Bank_Rule_GLAM__c> deleteBankRuleGLAMs = new List<Bank_Rule_GLAM__c>();

        List<Id> existingRuleGLAMs = new List<Id>();
        for (Bank_Rule_GLAM__c ruleGLAM : getRuleGLAMs(ruleId)) {
            existingRuleGLAMs.add(ruleGLAM.GL_Account_Mapping__c);

            if (!glams.contains(ruleGLAM.GL_Account_Mapping__c)) {
                deleteBankRuleGLAMs.add(ruleGLAM);
            }
        }

        for (Id glam : glams) {
            if (!existingRuleGLAMs.contains(glam)) {
                insertBankRuleGLAMs.add(new Bank_Rule_GLAM__c(
                    Bank_Rule__c = ruleId,
                    GL_Account_Mapping__c = glam
                ));
            }
        }

        if (insertBankRuleGLAMs.size() > 0) {
            SFDCSecurityUtils.insertCheckCRUDAndFLS(insertBankRuleGLAMs, new List<String>{
                'GL_Account_Mapping__c',
                'Bank_Rule__c'
            });
        }
        
        if (deleteBankRuleGLAMs.size() > 0) {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteBankRuleGLAMs);
        }
     }

    private static Bank_Rule__c getRule(ID ruleId) {
        List<String> ruleFields = new List<String> {
            'Id',
            'Name',
            'Active__c',
            'Priority__c',
            'Type__c',
            'Evaluation_Type__c',
            'Source_Record_Type__c',
            'Description__c',
            'Apply_To_All_Financial_Accounts__c'
        };
        String ruleCondition = 'Id = :ruleId';

        SOQLBuilder ruleQuery = new SOQLBuilder(Bank_Rule__c.SObjectType);
        ruleQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(ruleFields)
            .setCondition(ruleCondition)
            .setLimit(1);

        return (Bank_Rule__c) Database.query(ruleQuery.toSOQL());
    }

    private static List<Bank_Rule_GLAM__c> getRuleGLAMs(ID ruleId) {
        List<String> conditionFields = new List<String> {
            'Id',
            'GL_Account_Mapping__c'
        };
        String ruleGLAMCondition = 'Bank_Rule__c = :ruleId AND GL_Account_Mapping__r.Inactive__c = FALSE';

        SOQLBuilder ruleGLAMQuery = new SOQLBuilder(Bank_Rule_GLAM__c.SObjectType);
        ruleGLAMQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(conditionFields)
            .setCondition(ruleGLAMCondition);

        return (List<Bank_Rule_GLAM__c>) Database.query(ruleGLAMQuery.toSOQL());
    }

    private static List<Bank_Rule_Condition__c> getRuleConditions(ID ruleId) {
        List<String> conditionFields = new List<String> {
            'Id',
            'Bank_Rule__c',
            'Target_Field__c',
            'Operator__c',
            'Amount__c',
            'Description__c',
            'High_Level_Category__c',
            'Category__c',
            'Detail_Category__c',
            'Base_Type__c',
            'Type__c'
        };
        String conditionCondition = 'Bank_Rule__c = :ruleId';

        SOQLBuilder conditionQuery = new SOQLBuilder(Bank_Rule_Condition__c.SObjectType);
        conditionQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(conditionFields)
            .setCondition(conditionCondition);

        return (List<Bank_Rule_Condition__c>) Database.query(conditionQuery.toSOQL());
    }

    private static List<Bank_Rule_Action__c> getRuleActions(ID ruleId) {
        List<String> actionFields = new List<String> {
            'Id',
            'Bank_Rule__c',
            'Target_Field__c',
            'Value__c'
        };
        String actionCondition = 'Bank_Rule__c = :ruleId';

        SOQLBuilder actionQuery = new SOQLBuilder(Bank_Rule_Action__c.SObjectType);
        actionQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(actionFields)
            .setCondition(actionCondition);

        return (List<Bank_Rule_Action__c>) Database.query(actionQuery.toSOQL());
    }

}