/**
 * Entry point for amortization functionality.
 */
global with sharing class Amortization {

    global class AmortizationException extends Exception{}
    @TestVisible
    private static final String MISSING_OPTIONS = Label.ERR_NO_AMORTIZATION_OPTIONS;
    @TestVisible
    private static final String INVALID_SRC_DOC_TYPE = Label.ERR_INVALID_SRC_DOC_TYPE_AMORTIZATION;
    @TestVisible
    private static final String INVALID_AMORTIZATION_METHOD = Label.ERR_INVALID_AMORTIZATION_METHOD;
    @TestVisible
    private static final String ERROR_START_DATE_GREATER_END_DATE = Label.START_DATE_ERROR;
    @TestVisible
    private static final String ERROR_START_DATE_EMPTY = Label.COMMON_ERROR_START_DATE_EMPTY;
    public static final String ERROR_NO_OPEN_PERIODS = Label.ERR_NO_OPEN_ACCOUNTING_PERIOD_IN_DATE_RANGE_AMORTIZATION;

    private APIServiceContext.APIServiceEntry serviceEntry;
    @TestVisible
    private AmortizationMethodFactory methodFactory;

    private final Map<SObjectType, List<SObjectField>> fieldsBySObjectType = new Map<SObjectType, List<SObjectField>>{
        Billing__c.SObjectType => new List<SObjectField>{
            Billing__c.Name,
            Billing__c.Ledger__c,
            Billing__c.Customer__c,
            Billing__c.Total__c,
            Billing__c.Ledger_Amount__c,
            Billing__c.Sub_Total__c,
            Billing__c.Currency_Conversion_Rate__c
        },
        Account_Payable__c.SObjectType => new List<SObjectField>{
            Account_Payable__c.Name,
            Account_Payable__c.Ledger__c,
            Account_Payable__c.Vendor__c,
            Account_Payable__c.Total__c,
            Account_Payable__c.Ledger_Amount__c,
            Account_Payable__c.Sub_Total__c,
            Account_Payable__c.Currency_Conversion_Rate__c
        },
        Fixed_Asset__c.SObjectType => new List<SObjectField>{
            Fixed_Asset__c.Name,
            Fixed_Asset__c.Ledger__c,
            Fixed_Asset__c.Value__c
        }
    };


    global Amortization() {
        this.methodFactory = new AmortizationMethodFactory();
        this.serviceEntry = new APIServiceContext.APIServiceEntry();
    }

    @InvocableMethod(label='Amortize Records')
    global static List<AmortizationResult> amortizeInvocable(List<AmortizationOptions> amortizationOptions) {
        Amortization amor = new Amortization();
        List<AmortizationResult> ar = amor.amortize(amortizationOptions);
        return ar;
    }

    /**
     * Given a set of options creates an amortization schedule of `Scheduled_Revenue_Expense__c`s.
     * @param options - Options used to create a series of `Scheduled_Revenue_Expense__c`s.
     */
    global AmortizationResult amortize(AmortizationOptions options) {
        List<AmortizationOptions> opts = new List<AmortizationOptions>{ options };
        List<AmortizationResult> ar = this.amortize(opts);
        return ar[0];
    }

    /**
     * For each set of options creates amortization schedules of `Scheduled_Revenue_Expense__c`s.
     * @param options - Options used to create `Scheduled_Revenue_Expense__c`s.
     */
    global List<AmortizationResult> amortize(List<AmortizationOptions> options) {
        if (options == null || options.isEmpty()) {
            throw new AmortizationException(MISSING_OPTIONS);
        }
        ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
        if (!validationResult.isSuccess) {
            throw new AmortizationException(String.join(validationResult.errors, ','));
        }
        return this.processAmortizations(options);
    }

    /**
     * Performs the amortization logic for the provided options.
     */
    @TestVisible
    private List<AmortizationResult> processAmortizations(List<AmortizationOptions> options) {
        List<AmortizationResult> results = new List<AmortizationResult>();
        Map<Id, SObject> mRecords = this.getSourceObjects(options);
        for (AmortizationOptions option: options) {
            try {
                if (option == null) {
                    throw new AmortizationException(MISSING_OPTIONS);
                }
                if (!FinancialSuiteUtils.isValidId(option.sourceDocument, Billing__c.getSObjectType())
                        && !FinancialSuiteUtils.isValidId(option.sourceDocument, Account_Payable__c.getSObjectType())
                        && !FinancialSuiteUtils.isValidId(option.sourceDocument, Fixed_Asset__c.getSObjectType())) {
                    throw new AmortizationException(INVALID_SRC_DOC_TYPE);
                }

                AbstractAmortization method = this.methodFactory.locate(option.amortizationMethod);
                if (method == null) {
                    throw new AmortizationException(INVALID_AMORTIZATION_METHOD);
                }
                method.validateAmortizationOptions(option, mRecords.get(option.sourceDocument));
                method.setOptions(option);
                results.add(method.amortize(option, mRecords.get(option.sourceDocument)));
            } catch(Exception error) {
                AmortizationResult result = new AmortizationResult();
                result.isSuccess = false;
                result.errors.add(error.getMessage());
                results.add(result);
            }
        }

        return results;
    }


    public static void validateStartDate(Date startDate) {
        if (startDate == null) {
            throw new AmortizationException(ERROR_START_DATE_EMPTY);
        }
    }

    public static void validateAccountMethod(AmortizationOptions options, SObject sourceDocument) {
        Id ledgerId = (Id) sourceDocument.get(GlobalVariables.PACKAGE_QUALIFIER +'Ledger__c');
        if (String.isNotBlank(ledgerId)) {
            if (LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(ledgerId)
                    && options.accrualCash != LedgerActions.ACCOUNTING_METHOD_ACCRUAL) {
                throw new AmortizationException(String.format(
                        Label.ERR_ONLY_SOURCE_WITH_CORRECT_ACCOUNTING_METHOD,
                        new List<String>{ LedgerActions.ACCOUNTING_METHOD_ACCRUAL }
                ));
            } else if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(ledgerId)
                    && options.accrualCash != LedgerActions.ACCOUNTING_METHOD_CASH) {
                throw new AmortizationException(String.format(
                        Label.ERR_ONLY_SOURCE_WITH_CORRECT_ACCOUNTING_METHOD,
                        new List<String>{ LedgerActions.ACCOUNTING_METHOD_CASH }
                ));
            }
        }
    }

    public static void validateEndDate(Date startDate, Date endDate) {
        if (endDate == null) {
            throw new AmortizationException(Label.ERR_END_DATE_CANNOT_BE_EMPTY);
        }
        if (startDate > endDate) {
            throw new AmortizationException(ERROR_START_DATE_GREATER_END_DATE);
        }
    }

    public static void validatePeriods(List<Accounting_Period__c> acctPeriods, Date startDate, Date endDate) {
        validatePeriods(acctPeriods, startDate);
        if (acctPeriods[acctPeriods.size() - 1].End_Date__c < endDate) {
            throw new AmortizationException(ERROR_NO_OPEN_PERIODS);
        }
    }

    public static void validatePeriods(List<Accounting_Period__c> acctPeriods, Date startDate) {
        if (acctPeriods == null 
            || acctPeriods.isEmpty()
            || (acctPeriods[0].Start_Date__c > startDate)
        ) {
            throw new AmortizationException(ERROR_NO_OPEN_PERIODS);
        }

    }

    private Map<Id, SObject> getSourceObjects(List<AmortizationOptions> options) {
        List<SObject> sObjects = new List<SObject>();
        Map<SObjectType, Set<Id>> types = new Map<SObjectType, Set<Id>>();
        for (AmortizationOptions option : options) {
            if (option == null) {
                continue;
            }
            if (!types.keySet().contains(option.sourceDocument.getSObjectType())) {
                types.put(option.sourceDocument.getSObjectType(), new Set<Id> {option.sourceDocument});
            }
            else {
                types.get(option.sourceDocument.getSObjectType()).add(option.sourceDocument);
            }
        }

        if(types.containsKey(Account_Payable__c.SObjectType)) {
            sObjects.addAll(querySobjectsByType(Account_Payable__c.SObjectType, types.get(Account_Payable__c.SObjectType)));
        }
        if(types.containsKey(Billing__c.SObjectType)) {
            sObjects.addAll(querySobjectsByType(Billing__c.SObjectType, types.get(Billing__c.SObjectType)));
        }
        if(types.containsKey(Fixed_Asset__c.SObjectType)) {
            sObjects.addAll(querySobjectsByType(Fixed_Asset__c.SObjectType, types.get(Fixed_Asset__c.SObjectType)));
        }

        return new Map<Id, SObject>(sObjects);
    }

    private List<SObject> querySobjectsByType(SObjectType objType, Set<Id> ids) {
        String query = '';
        for (SObjectField fieldName : fieldsBySObjectType.get(objType)){
            query += fieldName + ', ';
        }
        query = query.removeEnd(', ');
        return Database.query('SELECT ' + query + ' FROM ' + objType + ' WHERE Id IN :ids WITH SECURITY_ENFORCED LIMIT 50000 ');
    }
    public static void validateNumberOfPeriod(Integer numberOfPeriod){
        if (numberOfPeriod == null) {
            throw new AmortizationException(Label.ERR_NUMBER_OF_ACCOUNTING_PERIOD_CANNOT_BE_EMPTY);
        }
    }
}