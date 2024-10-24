public with sharing abstract class AbstractAvaTaxController {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static final String POSTED_RECORD_ERROR_MESSAGE = Label.ERR_AVATAX_CANNOT_CALC_POSTED;
    public static final String NO_LINES_ERROR_MESSAGE = Label.ERR_AVATAX_NO_CALC_LINES;
    public static final String INCORRECT_CURRENCY_ERROR_MESSAGE = Label.ERR_AVATAX_ONLY_USD_LEDGER;
    public static final String APPLIED_RECORD_ERROR_MESSAGE = Label.ERR_AVATAX_CANNOT_APPLIED_CALCULATED;
    public static final String SHIPPING_ADDRESS_MISSING_WARNING_MESSAGE = Label.WNG_AVATAX_SHIPPING_ADDRESS_MISSING;
    public static final String NO_TAXABLE_LINES_FOUND_WARNING_MESSAGE = Label.WNG_AVATAX_NO_TAXABLE_LINES_FOUND;
    public Integer ldvCalcTaxLineLimit = 2000;

    public abstract AvaTaxService.AvaTaxResult pushAvaTaxTransaction();

    protected SObject sourceRecord;
    protected Id sourceRecordId;
    protected List<SObject> sourceRecordLines = new List<SObject>();
    public Boolean isMultiCurrencyEnabled  {
        get {
            return MultiCurrencyHandler.isMultiCurrencyEnabled;
        }
    }

    protected Boolean validateTaxableBillingLineExists() {
        Integer taxableLineCounter = 0;
        for (Billing_Line__c bl : (List<Billing_Line__c>) sourceRecordLines) {
            if (AvaTaxHelper.validateBillingLineIsTaxable(bl, sourceRecord)) {
                taxableLineCounter++;
            }
        }
        return taxableLineCounter > 0;
    }

}