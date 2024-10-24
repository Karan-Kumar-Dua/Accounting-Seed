public with sharing class GLAccountDefaultActions {
    public static final String BANK_RESTRICTION_MUST_BE_BLANK = 'Must be Bank';
    public static final String BANK_RESTRICTION_MUST_NOT_BE_BLANK = 'Must NOT be Bank';
    public static final String CASH_FLOW_RESTRICTION_MUST_BE = 'Must be Cash Flow Category';
    public static final String CASH_FLOW_RESTRICTION_MUST_NOT_BE = 'Must NOT be Cash Flow Category';

    public static final String GL_TYPE_ANY = 'Any';
    public static final String GL_SUB_TYPE_ANY = 'Any';

    public static final String UNIQUE_GL_ACCOUNT_ERROR = Label.ERR_UNIQUE_GL_ACCOUNT_DEFAULTS;
    public static final String UNIQUE_AMORT_GL_ACCOUNT_ERROR = Label.ERR_UNIQUE_AMORT_GL_ACCOUNT;
    public static final String UNIQUE_DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR = Label.ERR_GL_ACCT_DEF_DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT_UNIQUE;

    public static final Set<String> specsWithUniqueGlAccount = new Set<String>{
            GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT,
            GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT,
            GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT,
            GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT,
            GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT,
            GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT,
            GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT,
            GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT,
            GLAccountDefaultsHandler.LABOR_GL_ACCOUNT,
            GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT,
            GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT,
            GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT,
            GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT,
            GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT,
            GLAccountDefaultsHandler.WORK_IN_PROCESS_GL_ACCOUNT,
            GLAccountDefaultsHandler.CTA_GL_ACCOUNT
    };

    private static final Set<String> notAllowedInAmortizationSpecDevNames = new Set<String>{
            GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT,
            GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT,
            GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT,
            GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT,
            GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT,
            GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT,
            GLAccountDefaultsHandler.CTA_GL_ACCOUNT
    };

    private static final Set<String> amortizationSpecDevNames = new Set<String>{
            GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE,
            GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_REVENUE,
            GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_EXPENSE,
            GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE
    };

    public static final Map<String, Set<String>> allowedSameGlAccount = new Map<String, Set<String>> {
            GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT => new Set<String>{
                    GLAccountDefaultsHandler.LABOR_GL_ACCOUNT
            },
            GLAccountDefaultsHandler.LABOR_GL_ACCOUNT => new Set<String>{
                    GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT
            }
    };

    public static Boolean isPreventUpdateOverride = false;

    public static void setUniqueKeys(List<GL_Account_Default__c> glAccountDefaults) {
        for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
            glAccountDefault.Unique_Key__c = String.join(new List<String>{
                    glAccountDefault.GL_Account_Specification__c,
                    glAccountDefault.Ledger__c
            }, ':');
        }
    }

    public static void validate(List<GL_Account_Default__c> glAccountDefaults) {
        validate(glAccountDefaults, null);
    }

    public static void validate(List<GL_Account_Default__c> glAccountDefaults, Map<Id, GL_Account_Default__c> oldGLAccountDefaultsByIds) {
        if (isPreventUpdateOverride) {
            return;
        }

        Set<String> specificationDevNames = new Set<String>();
        Set<Id> glAccountIds = new Set<Id>();
        Set<Id> ledgerIds = new Set<Id>();
        for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
            specificationDevNames.add(glAccountDefault.GL_Account_Specification__c);
            glAccountIds.add(glAccountDefault.GL_Account__c);
            ledgerIds.add(glAccountDefault.Ledger__c);
            if (oldGLAccountDefaultsByIds != null) {
                glAccountIds.add(oldGLAccountDefaultsByIds.get(glAccountDefault.Id).GL_Account__c);
                ledgerIds.add(oldGLAccountDefaultsByIds.get(glAccountDefault.Id).Ledger__c);
            }
        }

        Map<Id, GL_Account__c> glAccountsByIds = new Map<Id, GL_Account__c>(DomainUtils.getGlAccountsById(glAccountIds));
        Map<Id, Map<Id, AggregateResult>> glAccountWithCubeCountByGLAccountIds = glAccountWithCubeCountByGLAccountIds(glAccountIds, ledgerIds);
        Map<String, GL_Account_Specification__mdt> glAccountSpecificationsByDevNames =
                GLAccountDefaultsHandler.glAccountSpecificationsByDevNames(DomainUtils.glAccountSpecifications(specificationDevNames));

        for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
            GL_Account__c glAccount = glAccountsByIds.get(glAccountDefault.GL_Account__c);
            Boolean isGLAccountChanged = oldGLAccountDefaultsByIds != null
                    && glAccountDefault.GL_Account__c != oldGLAccountDefaultsByIds.get(glAccountDefault.Id).GL_Account__c;

            GL_Account_Specification__mdt specification = glAccountSpecificationsByDevNames.get(glAccountDefault.GL_Account_Specification__c);
            if (specification != null) {
                Boolean isSupportedType = specification.Allowed_GL_Types__c == GL_TYPE_ANY
                        || specification.Allowed_GL_Types__c == glAccount.Type__c;
                Boolean isSupportedSubType = specification.Allowed_GL_Sub_Type_1__c == GL_SUB_TYPE_ANY
                        || specification.Allowed_GL_Sub_Type_1__c == glAccount.Sub_Type_1__c;
                if (!isSupportedType || specification.Allowed_GL_Sub_Type_1__c != GL_SUB_TYPE_ANY) {
                    if (specification.Allowed_GL_Sub_Type_1__c != GL_SUB_TYPE_ANY && (!isSupportedSubType || !isSupportedType)) {
                        glAccountDefault.GL_Account__c.addError(String.format(GLAccountValidator.NON_VALID_TYPE_AND_SUBTYPE1_ERROR, new List<String>{
                                specification.Allowed_GL_Types__c, specification.Allowed_GL_Sub_Type_1__c
                        }));
                    }
                    else if (!isSupportedType && specification.Allowed_GL_Sub_Type_1__c == GL_SUB_TYPE_ANY) {
                        glAccountDefault.GL_Account__c.addError(String.format(GLAccountValidator.NON_VALID_TYPE_ERROR, new List<String>{specification.Allowed_GL_Types__c}));
                    }
                }
                if (specification.Bank_Restriction__c == BANK_RESTRICTION_MUST_BE_BLANK && !glAccount.Bank__c) {
                    glAccountDefault.GL_Account__c.addError(GLAccountValidator.NOT_BANK_ERROR);
                }
                if (specification.Bank_Restriction__c == BANK_RESTRICTION_MUST_NOT_BE_BLANK && glAccount.Bank__c) {
                    glAccountDefault.GL_Account__c.addError(GLAccountValidator.IS_BANK_ERROR);
                }
                if (specification.Cash_Flow_Category_Restriction__c == CASH_FLOW_RESTRICTION_MUST_BE
                        && (glAccount.Type__c != 'Cash Flow')) {
                    glAccountDefault.GL_Account__c.addError(GLAccountValidator.NOT_CASH_FLOW_CATEGORY_ERROR);
                }
                if (specification.Cash_Flow_Category_Restriction__c == CASH_FLOW_RESTRICTION_MUST_NOT_BE
                        && (glAccount.Type__c == 'Cash Flow')) {
                    glAccountDefault.GL_Account__c.addError(GLAccountValidator.IS_CASH_FLOW_CATEGORY_ERROR);
                }
                if (oldGLAccountDefaultsByIds == null && specification.Restrict_Existing_Transactions_on_Create__c
                        && glAccountWithCubeCountByGLAccountIds?.get(glAccountDefault.Ledger__c)?.get(glAccountDefault.GL_Account__c) != null) {
                    glAccountDefault.GL_Account__c.addError(String.format(GLAccountValidator.EXISTED_TRANSACTION_ERROR, new List<String>{glAccount.Name}));
                }
                if (isGLAccountChanged && specification.Restrict_Existing_Transactions_on_Edit__c) {
                    GL_Account__c oldGLAccount = glAccountsByIds.get(oldGLAccountDefaultsByIds.get(glAccountDefault.Id).GL_Account__c);
                    if (oldGLAccount != null && glAccountWithCubeCountByGLAccountIds?.get(glAccountDefault.Ledger__c)?.get(oldGLAccount.Id) != null) {
                        glAccountDefault.GL_Account__c.addError(String.format(GLAccountValidator.EXISTED_TRANSACTION_ERROR, new List<String>{oldGLAccount.Name}));
                    }
                }
            } else {
                glAccountDefault.GL_Account_Specification__c.addError(Label.COMMON_SPECIFICATION_NOT_FOUND);
            }
        }

        checkUniqueness(glAccountDefaults, oldGLAccountDefaultsByIds);
    }

    private static void checkUniqueness(List<GL_Account_Default__c> glAccountDefaults, Map<Id, GL_Account_Default__c> oldGLAccountDefaultsByIds) {
        Set<String> changedSpecDevNames = new Set<String>();
        Map<String, Id> changedGLAccountIdsBySpecDevNames = new Map<String, Id>();
        for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
            if (oldGLAccountDefaultsByIds == null || glAccountDefault.GL_Account__c != oldGLAccountDefaultsByIds.get(glAccountDefault.Id).GL_Account__c) {
                changedSpecDevNames.add(glAccountDefault.GL_Account_Specification__c);
                if (String.isNotBlank(glAccountDefault.GL_Account__c)) {
                    changedGLAccountIdsBySpecDevNames.put(glAccountDefault.GL_Account_Specification__c, glAccountDefault.GL_Account__c);
                }
            }
        }
        for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
            String currentSpecDevName = glAccountDefault.GL_Account_Specification__c;
            List<String> errors = new List<String>();
            if (specsWithUniqueGlAccount.contains(currentSpecDevName)) {
                Set<String> specsWithUniqueGlAccount = new Set<String>(specsWithUniqueGlAccount);
                specsWithUniqueGlAccount.remove(currentSpecDevName);
                specsWithUniqueGlAccount.removeAll(changedSpecDevNames);
                if (allowedSameGlAccount.get(currentSpecDevName) != null) {
                    specsWithUniqueGlAccount.removeAll(allowedSameGlAccount.get(currentSpecDevName));
                }
                Map<Id, String> specsByUniqueGlAccountIds = specsByUniqueGlAccountIds(glAccountDefault.Ledger__c, specsWithUniqueGlAccount);

                Map<Id, String> retainSpecDevNamesByChangedGLAccountIds = fetchIntersectionItems(specsWithUniqueGlAccount, changedGLAccountIdsBySpecDevNames, currentSpecDevName);
                specsByUniqueGlAccountIds.putAll(retainSpecDevNamesByChangedGLAccountIds);

                if (specsByUniqueGlAccountIds.containsKey(glAccountDefault.GL_Account__c)
                        && specsByUniqueGlAccountIds.get(glAccountDefault.GL_Account__c) == GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT) {
                    errors.add(UNIQUE_DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR);
                } else if (specsByUniqueGlAccountIds.containsKey(glAccountDefault.GL_Account__c)) {
                    errors.add(UNIQUE_GL_ACCOUNT_ERROR);
                }
            }

            if (notAllowedInAmortizationSpecDevNames.contains(currentSpecDevName)) {
                Map<Id, String> specsByUniqueGlAccountIds = specsByUniqueGlAccountIds(glAccountDefault.Ledger__c, amortizationSpecDevNames);
                if (specsByUniqueGlAccountIds.containsKey(glAccountDefault.GL_Account__c)) {
                    errors.add(UNIQUE_GL_ACCOUNT_ERROR);
                }
            } else if (amortizationSpecDevNames.contains(currentSpecDevName)) {
                Map<Id, String> specsByUniqueGlAccountIds = specsByUniqueGlAccountIds(glAccountDefault.Ledger__c, notAllowedInAmortizationSpecDevNames);
                if (specsByUniqueGlAccountIds.containsKey(glAccountDefault.GL_Account__c)) {
                    errors.add(UNIQUE_AMORT_GL_ACCOUNT_ERROR);
                }
            }

            if (!errors.isEmpty()) {
                glAccountDefault.GL_Account__c.addError(errors[0]);
            }
        }

    }

    private static Map<Id, String> fetchIntersectionItems(Set<String> specsWithUniqueGlAccount, Map<String, Id> changedGLAccountIdsBySpecDevNames, String currentSpecDevName) {
        Map<Id, String> retainSpecDevNamesByChangedGLAccountIds = new Map<Id, String>();
        for (String specDevName : specsWithUniqueGlAccount) {
            if (changedGLAccountIdsBySpecDevNames.containsKey(specDevName) && specDevName != currentSpecDevName) {
                retainSpecDevNamesByChangedGLAccountIds.put(changedGLAccountIdsBySpecDevNames.get(specDevName), specDevName);
            }
        }
        return retainSpecDevNamesByChangedGLAccountIds;
    }

    private static Map<Id, String> specsByUniqueGlAccountIds(Id ledgerId, Set<String> specDevNames) {
        Map<Id, String> specsByUniqueGlAccountIds = new Map<Id, String>();
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames =
                GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);

        if (specDevNames.contains(GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT)) {
            defaultsBySpecDevNames.put(
                    GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT,
                    new GL_Account_Default__c(GL_Account__c = AccountingSettingsHandler.getAccountingSettings().Default_Project_Task_Labor_GL_Account__c)
            );
            specsByUniqueGlAccountIds.put(
                    AccountingSettingsHandler.getAccountingSettings().Default_Project_Task_Labor_GL_Account__c,
                    GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT
            );
        }

        for (String specDevName : specDevNames) {
            if (String.isNotBlank(defaultsBySpecDevNames?.get(specDevName)?.GL_Account__c)
                    && !specsByUniqueGlAccountIds.containsKey(defaultsBySpecDevNames?.get(specDevName)?.GL_Account__c)) {
                specsByUniqueGlAccountIds.put(defaultsBySpecDevNames?.get(specDevName)?.GL_Account__c, defaultsBySpecDevNames?.get(specDevName)?.GL_Account_Specification__c);
            }
        }
        return specsByUniqueGlAccountIds;
    }

    private static Map<Id, Map<Id, AggregateResult>> glAccountWithCubeCountByGLAccountIds(Set<Id> glAccountIds, Set<Id> ledgerIds) {
        Map<Id, Map<Id, AggregateResult>> glAccountWithCubeCountByGLAccountIds = new Map<Id, Map<Id, AggregateResult>>();
        try {
            glAccountWithCubeCountByGLAccountIds = DomainUtils.getGLAccountsWithFinCubesCount(glAccountIds, ledgerIds);
        } catch (QueryException qEx) {
            //In case of non-selective query our assumption is that each GL Account has at least one related FC
            //Only the key matters in the map, so values can be nulls
            for (Id ledgerId : ledgerIds) {
                for (Id glAccountId : glAccountIds) {
                    if (!glAccountWithCubeCountByGLAccountIds.containsKey(ledgerId)) {
                        glAccountWithCubeCountByGLAccountIds.put(ledgerId, new Map<Id, AggregateResult>());
                    }
                    glAccountWithCubeCountByGLAccountIds.get(ledgerId).put(glAccountId, null);
                }
            }
        }

        return glAccountWithCubeCountByGLAccountIds;
    }
}