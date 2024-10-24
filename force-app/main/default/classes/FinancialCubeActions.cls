public with sharing class FinancialCubeActions {

    public static final String FINANCIAL_CUBE_CONSOLIDATIONS = 'Consolidations';
    public static final String FINANCIAL_CUBE_PERIOD = 'Period';
    public static final String FINANCIAL_CUBE_CASH_FLOW = 'Cash Flow';
    public static final String FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS = 'Current Year Earnings';
    public static final String FINANCIAL_CUBE_RETAINED_EARNINGS = 'Retained Earnings';
    public static final List<SObjectField> nonUpdateableFields = new List<SObjectField> {
        Financial_Cube__c.GL_Account__c,
        Financial_Cube__c.Cube_Type__c,
        Financial_Cube__c.Accounting_Period__c,
        Financial_Cube__c.Year__c,
        Financial_Cube__c.Opening_Balance__c,
        Financial_Cube__c.GL_Account_Variable_1__c,
        Financial_Cube__c.GL_Account_Variable_2__c,
        Financial_Cube__c.GL_Account_Variable_3__c,
        Financial_Cube__c.GL_Account_Variable_4__c,
        Financial_Cube__c.Ledger__c,
        Financial_Cube__c.Source_Cube__c,
        Financial_Cube__c.IsTranslatedCube__c,
        Financial_Cube__c.Translation_Name__c,
        Financial_Cube__c.Key__c,
        Financial_Cube__c.Translated_Rate__c
    };
    public static final List<SObjectField> translatedFields = new List<SObjectField> {
        Financial_Cube__c.Source_Cube__c,
        Financial_Cube__c.IsTranslatedCube__c,
        Financial_Cube__c.Translation_Name__c,
        Financial_Cube__c.Translated_Rate__c
    };
    public static final String CONSOLIDATION_FINANCE_CUBE_4_CONSOLIDATION_LEDGER_ERROR = Label.ERR_CONSOLIDATION_FINANCE_CUBE_4_CONSOLIDATION_LEDGER;
    public static final String INSERT_ERROR = Label.ERR_FINANCE_CUBE_LEDGER_INSERT;
    public static final String UPDATE_ERROR = Label.ERR_FINANCE_CUBE_LEDGER_UPDATE;
    public static final String DELETE_ERROR = Label.ERR_FINANCE_CUBE_LEDGER_DELETE;
    public static Boolean isPreventOverride = false;

    private static Set<String> preventUpdateCubeTypes = new Set<String>{
        FINANCIAL_CUBE_RETAINED_EARNINGS, FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS, FINANCIAL_CUBE_CONSOLIDATIONS
    };

    public static void clearArchivedAmountOnInsert(List<Financial_Cube__c> fCubeList) {
        for (Financial_Cube__c fCube : fCubeList) {
            fCube.Archived_Amount__c = NULL;
        }
    }

    public static void validateRequiredFields(List<Financial_Cube__c> fCubeList) {
        for (Financial_Cube__c fCube : fCubeList) {
            if (fCube.Ledger__c == NULL) {
                fCube.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (fCube.Accounting_Period__c == NULL) {
                fCube.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (fCube.GL_Account__c == NULL) {
                fCube.GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setRequiredCubeFields(List<Financial_Cube__c> fCubeList) {

        Map<Id, Accounting_Period__c> acctPeriods = new Map<Id, Accounting_Period__c>();

        for (Financial_Cube__c fCube : fCubeList) {
            if (fCube.Accounting_Period__c != NULL) {
                acctPeriods.put(fCube.Accounting_Period__c, NULL);
            }
        }

        for (Accounting_Period__c acctPeriod : AccountingPeriodHandler.getInstance().getAccountingPeriodsById(acctPeriods.keySet())) {
            acctPeriods.put(acctPeriod.Id, acctPeriod);
        }

        for (Financial_Cube__c fCube : fCubeList) {

            if (MultiCurrencyHandler.isMultiCurrencyEnabled && fCube.Ledger__c != NULL &&
                (String.isBlank(fCube.Source_Cube__c) || fCube.get('CurrencyIsoCode') == null) && !fCube.IsTranslatedCube__c) {
                fCube.put('CurrencyIsoCode', LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(fCube.Ledger__c).get('CurrencyIsoCode'));
            }

            if (!fCube.IsTranslatedCube__c) {
                String ledger = fCube.Ledger__c != NULL ? String.valueOf(fCube.Ledger__c) : 'null';
                String acctPeriod = fCube.Accounting_Period__c != NULL ? String.valueOf(fCube.Accounting_Period__c) : 'null';
                String glAccount = fCube.GL_Account__c != NULL ? String.valueOf(fCube.GL_Account__c) : 'null';
                String acctVar1 = fCube.GL_Account_Variable_1__c != NULL ? String.valueOf(fCube.GL_Account_Variable_1__c) : 'null';
                String acctVar2 = fCube.GL_Account_Variable_2__c != NULL ? String.valueOf(fCube.GL_Account_Variable_2__c) : 'null';
                String acctVar3 = fCube.GL_Account_Variable_3__c != NULL ? String.valueOf(fCube.GL_Account_Variable_3__c) : 'null';
                String acctVar4 = fCube.GL_Account_Variable_4__c != NULL ? String.valueOf(fCube.GL_Account_Variable_4__c) : 'null';

                fCube.Amount__c = fCube.Amount__c != NULL ? fCube.Amount__c : 0;
                fCube.Key__c =
                    String.join(new List<String>{
                        acctPeriod,
                        ledger,
                        fCube.Cube_Type__c.remove(' '),
                        glAccount,
                        acctVar1,
                        acctVar2,
                        acctVar3,
                        acctVar4
                    }, '');
                fCube.Key_Group__c =
                    String.join(new List<String>{
                        ledger,
                        fCube.Cube_Type__c.remove(' '),
                        glAccount,
                        acctVar1,
                        acctVar2,
                        acctVar3,
                        acctVar4
                    }, '');
            }
            fCube.Year__c =
                (fCube.Year__c == NULL && acctPeriods.containsKey(fCube.Accounting_Period__c))
                    ? acctPeriods.get(fCube.Accounting_Period__c).Start_Date__c.year()
                    : fCube.Year__c;
        }

    }

    public static void validateCubeType(Map<Id, Financial_Cube__c> newCubeMap) {
        for (Financial_Cube__c financialCube : newCubeMap.values()) {
            if (LedgerHandler.isConsolidationLedger(financialCube.Ledger_Type__c)
                    && financialCube.Cube_Type__c != FINANCIAL_CUBE_CONSOLIDATIONS) {

                financialCube.Cube_Type__c.addError(CONSOLIDATION_FINANCE_CUBE_4_CONSOLIDATION_LEDGER_ERROR);
            } else if (!LedgerHandler.isConsolidationLedger(financialCube.Ledger_Type__c)
                            && financialCube.Cube_Type__c == FINANCIAL_CUBE_CONSOLIDATIONS) {

                financialCube.Ledger__c.addError(CONSOLIDATION_FINANCE_CUBE_4_CONSOLIDATION_LEDGER_ERROR);
            }
        }
    }

    public static void preventUpdateAction(Map<Id, Financial_Cube__c> oldCubeMap, Map<Id, Financial_Cube__c> newCubeMap) {

        //Ability to bypass the validations for AS Support team
        setHelpdeskForcedBypass();
        //=====================================================

        if (!isPreventOverride) {
            for (Financial_Cube__c newCube : newCubeMap.values()) {
                Financial_Cube__c oldCube = oldCubeMap.get(newCube.Id);
                for (SObjectField fieldToken : nonUpdateableFields) {
                    if (FinancialSuiteUtils.isFieldValueChanged(fieldToken, oldCube, newCube)
                            && (LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c)
                                    || LedgerHandler.isTransactionalLedger(newCube.Ledger_Type__c)
                                    || isBudgetTranslationCube(oldCube)
                                    || isBudgetTranslationCube(newCube)
                                    || isBudgetTranslationFiledChanged(oldCube, fieldToken)
                                    || isBudgetTranslationFiledChanged(newCube, fieldToken)
                                    || oldCube.Cube_Type__c == FINANCIAL_CUBE_CONSOLIDATIONS)) {

                        newCube.addError(
                            prepareErrorMessage(
                                UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(nonUpdateableFields)),
                                LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c) ? oldCube : newCube
                            ),
                            false
                        );
                    }
                }

                // DO not allow updating the amount field on a financial cube if the f cube is a retained earnings or current year earnings cube
                if (oldCube.get(Financial_Cube__c.Amount__c) != newCube.get(Financial_Cube__c.Amount__c)
                        && ((LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c)
                                || LedgerHandler.isTransactionalLedger(newCube.Ledger_Type__c))
                                || isBudgetTranslationCube(oldCube)
                                || isBudgetTranslationCube(newCube)
                                || preventUpdateCubeTypes.contains(oldCube.Cube_Type__c)
                                || oldCube.Accounting_Period_Status__c == AccountingPeriodActions.ARCHIVED_STATUS)) {

                    newCube.addError(
                        prepareErrorMessage(
                            UPDATE_ERROR.replace('<FIELDS>', Financial_Cube__c.Amount__c.getDescribe().getLabel()),
                            LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c) ? oldCube : newCube
                        ),
                        false
                    );
                }

                //Lock down the archive amount field on the fin cube to prevent user from updating
                if ((oldCube.Archived_Amount__c != newCube.Archived_Amount__c)
                        && (LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c)
                                || LedgerHandler.isTransactionalLedger(newCube.Ledger_Type__c)
                                || oldCube.Cube_Type__c == FINANCIAL_CUBE_CONSOLIDATIONS)) {

                    newCube.addError(
                        prepareErrorMessage(
                            UPDATE_ERROR.replace('<FIELDS>', Financial_Cube__c.Archived_Amount__c.getDescribe().label),
                            LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c) ? oldCube : newCube
                        ),
                        false
                    );
                }
            }
        }

    }

    private static Boolean isBudgetTranslationCube(Financial_Cube__c cube) {
        return LedgerHandler.isBudgetLedger(cube.Ledger_Type__c) && cube.IsTranslatedCube__c;
    }

    private static Boolean isBudgetTranslationFiledChanged(Financial_Cube__c cube, SObjectField fieldToken) {
        return cube.Ledger_Type__c == LedgerActions.LEDGER_TYPE_BUDGET && translatedFields.contains(fieldToken);
    }

    public static void preventInsertAction(List<Financial_Cube__c> newCubes) {
        if (!isPreventOverride) {
            for (Financial_Cube__c newCube : newCubes) {
                //All "Transactional" Ledger Types not allowed for direct(manual) creation
                if (LedgerHandler.isTransactionalLedger(newCube.Ledger_Type__c)
                        || newCube.Cube_Type__c == FINANCIAL_CUBE_CONSOLIDATIONS
                        || isBudgetTranslationCube(newCube)) {

                    newCube.addError(prepareErrorMessage(INSERT_ERROR, newCube), false);
                }
            }
        }
    }

    public static void preventDeleteAction(Map<Id, Financial_Cube__c> oldCubesMap) {
        //Ability to bypass the validations for AS Support team
        setHelpdeskForcedBypass();
        //=====================================================

        for (Financial_Cube__c oldCube : DomainUtils.getFinancialCubesById(oldCubesMap.keySet())) {
            if (isPreventOverride) {
                break;
            }

            if (oldCube.Cube_Type__c == FINANCIAL_CUBE_CONSOLIDATIONS) {
                oldCubesMap.get(oldCube.Id).addError(prepareErrorMessage(DELETE_ERROR, oldCube), false);
            }
            else if (LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c)
                        && (oldCube.Cube_Type__c == FINANCIAL_CUBE_PERIOD && oldCube.Accounting_Period_Status__c != AccountingPeriodActions.ARCHIVED_STATUS
                                && ((oldCube.Financial_Cube_Transactions__r != NULL && !oldCube.Financial_Cube_Transactions__r.isEmpty())
                                        || oldCube.Opening_Balance__c != 0))) {

                oldCubesMap.get(oldCube.Id).addError(prepareErrorMessage(DELETE_ERROR, oldCube), false);
            }
            else if (LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c)
                        && (oldCube.Cube_Type__c == FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS
                                || oldCube.Cube_Type__c == FINANCIAL_CUBE_RETAINED_EARNINGS)) {

                oldCubesMap.get(oldCube.Id).addError(prepareErrorMessage(DELETE_ERROR, oldCube), false);
            }
            else if (LedgerHandler.isTransactionalLedger(oldCube.Ledger_Type__c)
                        && oldCube.Accounting_Period_Status__c == AccountingPeriodActions.ARCHIVED_STATUS) {

                oldCubesMap.get(oldCube.Id).addError(prepareErrorMessage(DELETE_ERROR, oldCube), false);
            }
        }
    }

    private static Set<Id> financialCubeIds4Deletion;

    public static void prepareTranslationCubesForDeletion(Map<Id, Financial_Cube__c> oldCubesMap) {
        financialCubeIds4Deletion = new Set<Id>();
        Set<Id> sourceCubeIds = new Set<Id>();
        for (Financial_Cube__c financialCube : oldCubesMap.values()) {
            if (!financialCube.IsTranslatedCube__c) {
                sourceCubeIds.add(financialCube.Id);
            }
        }
        if (!sourceCubeIds.isEmpty()) {
            financialCubeIds4Deletion.addAll(
                new Map<Id, Financial_Cube__c>(DomainUtils.getTranslatedCubesBySourceCubeIds(sourceCubeIds)).keySet()
            );
        }
    }

    public static void deleteTranslationCubes() {
        if (financialCubeIds4Deletion != null && !financialCubeIds4Deletion.isEmpty()) {
            List<Financial_Cube__c> cubesToDelete = DomainUtils.getFinancialCubes(financialCubeIds4Deletion);
            if (!cubesToDelete.isEmpty()) {
                FinancialCubeActions.isPreventOverride = true;
                SFDCSecurityUtils.deleteProxy(cubesToDelete);
                FinancialCubeActions.isPreventOverride = false;
            }
        }
    }

    private static String prepareErrorMessage(String msgTemplate, Financial_Cube__c financialCube) {
        return String.format(msgTemplate, new List<String>{
            financialCube.Ledger_Type__c
        });
    }

    public static void requireFields(List<Financial_Cube__c> newCubes) {
        for (Financial_Cube__c fc : newCubes) {
            if (fc.Ledger__c == NULL) {
                fc.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (fc.Accounting_Period__c == NULL) {
                fc.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    private static void setHelpdeskForcedBypass() {
        try {
            Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
            if (main.Financial_Suite_Key__c != NULL
                    && (main.Financial_Suite_Key__c == UserInfo.getOrganizationId()
                        || main.Financial_Suite_Key__c == UserInfo.getOrganizationId().left(15))) {

                isPreventOverride = true;
            }
        }
        catch (QueryException ex) {

        }
    }

}