public with sharing class FinancialReportColumnActions {
   
    public static final String POSITION_VALUE_ERROR = Label.ERR_POSITION_VALUE_GREATER_ZERO;
    public static final String BLANK_TYPE_ERROR = Label.ERR_BLANK_TYPE;
    public static final String INVALID_TYPE_ERROR = Label.ERR_INVALID_TYPE;
    public static final String EMPTY_CALCULATION_ERROR = Label.ERR_EMPTY_CALCULATION;
    public static final String USE_VALID_LEDGER = Label.ERR_VALID_LEDGER_COLUMN;

    //=== TYPE picklist values ==============================================
    public static final String FRC_TYPE_CURRENT_PERIOD = 'Current Period';
    public static final String FRC_TYPE_YEAR_TO_DATE = 'Year To Date';
    public static final String FRC_TYPE_OPENING_BALANCE = 'Opening Balance';
    public static final String FRC_TYPE_CALCULATION_NUMBER = 'Calculation Number';
    public static final String FRC_TYPE_CALCULATION_PERCENTAGE = 'Calculation Percentage';
    public static final String FRC_TYPE_CALCULATION_PERCENTAGE_SYMBOL = 'Calculation %';

    public static Set<ValidationType> preventValidationTypes = new Set<ValidationType>();

    private static Set<String> validColTypes = new Set<String> {
        FRC_TYPE_CURRENT_PERIOD,
        FRC_TYPE_YEAR_TO_DATE,
        FRC_TYPE_CALCULATION_NUMBER,
        FRC_TYPE_CALCULATION_PERCENTAGE,
        FRC_TYPE_CALCULATION_PERCENTAGE_SYMBOL/*legacy support*/
    };

    private static Set<String> calculationTypes = new Set<String> {
        FRC_TYPE_CALCULATION_NUMBER,
        FRC_TYPE_CALCULATION_PERCENTAGE,
        FRC_TYPE_CALCULATION_PERCENTAGE_SYMBOL/*legacy support*/
    };
    
    public static void validateColType(List<Financial_Report_Column__c> newFinReportCols) {
        
        for (Financial_Report_Column__c aCol : newFinReportCols) {
        
            if (!preventValidationTypes.contains(ValidationType.POSITION) && aCol.Position__c <= 0) {
                aCol.Position__c.addError(POSITION_VALUE_ERROR);
                continue;
            }

            if (aCol.Type__c == NULL) {
                aCol.Type__c.addError(BLANK_TYPE_ERROR);
                continue;
            }

            if (!validColTypes.contains(aCol.Type__c)) {
                aCol.Type__c.addError(INVALID_TYPE_ERROR);
                continue;
            }

            if (!preventValidationTypes.contains(ValidationType.CALCULATION) && aCol.Type__c.startsWith('Calculation') && aCol.Calculation__c == NULL) {
                aCol.Calculation__c.addError(EMPTY_CALCULATION_ERROR);
                continue;
            }

            if (aCol.Type__c != NULL && !calculationTypes.contains(aCol.Type__c) && aCol.Ledger__c == NULL) {
                //frc.Ledger__c.addError('You must select a valid Ledger for the column when using the \"' + frc.Type__c + '\" type');
                aCol.Ledger__c.addError(String.format(USE_VALID_LEDGER, new List<String>{aCol.Type__c}));
                continue;
            }

        }

    }

    public static void validateFormula(List<Financial_Report_Column__c> newFinReportCols) {
        
        for (Financial_Report_Column__c aCol : newFinReportCols) {
            
            if (!preventValidationTypes.contains(ValidationType.CALCULATION) && aCol.Type__c != NULL && aCol.Type__c.startsWith('Calculation') && aCol.Calculation__c != NULL) {
                
                Integer p = Integer.valueOf(aCol.Position__c);
                FinancialReportFormulaValidator f = new FinancialReportFormulaValidator(aCol.Calculation__c, FinancialReportFormulaValidator.FormulaTypes.COL, p, p);
                
                FinancialReportFormulaValidator.ValidationResult res = f.validate();

                if (res.errors != NULL && res.errors.size() > 0) {
                    for (FinancialReportFormulaValidator.ValidationResultError vr : res.errors) {
                        aCol.Calculation__c.addError(vr.message);
                    }
                    continue;
                }

            }

        }

    }

    public enum ValidationType {
        POSITION, CALCULATION
    }
}