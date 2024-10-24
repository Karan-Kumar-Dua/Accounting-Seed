/*
**   Created By    : AccountingSeed
**  Created For    : Deepclone for AccountPayable and AccountPayable Lines. 
** Created Date    : July 19, 2011
*/

public with sharing class AccountPayableDeepClone {

    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private ApexPages.StandardController controller {get; set;}
    private Account_Payable__c DCAccountPay {get;set;}
    private Id apId;
    private String apName;
    @TestVisible
    private Account_Payable__c cloneAcctPayable;
    private Account_Payable__c originalAcctPayable;
    @TestVisible
    private List<Account_Payable_Line__c> newAPLines;
    private Set<String> apFields;
    @TestVisible
    private Set<String> apLineFields;
    @TestVisible
    private Set<String> tempApLineFields = new Set<String>();
    @TestVisible

    public Account_Payable__c tempPayable {get; set;}
    public Id theNewPayableId {get; set;}
    public Boolean isError {get; set;}
    public Boolean isMultiCurrencyEnabled {get ;set;}
    public Boolean isCreditMemo {get; set;}
    public Boolean makeCreditMemo {get; set;}

    public static final String NO_OPEN_PERIOD_ERROR_MESSAGE = Label.ERR_NO_OPEN_ACCOUNTING_PERIOD;

    // Initialize the Controller
    public AccountPayableDeepClone(ApexPages.StandardController controller) {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        if (isMultiCurrencyEnabled && !Test.isRunningTest()) {
            controller.addFields(new List<String>{'CurrencyIsoCode'});
        }
        isError = false;
        apId = controller.getRecord().Id;
        apName = String.valueOf(controller.getRecord().get('Name'));
        theNewPayableId = apId;
        tempPayable = new Account_Payable__c();
        tempPayable.Date__c = System.today();
        makeCreditMemo = false;
        isCreditMemo = [SELECT ID, Type__c FROM Account_Payable__c WHERE ID=:apId].Type__c == 'Invoice' ? false : true;
        if (isMultiCurrencyEnabled) {
            tempPayable.put('CurrencyIsoCode', controller.getRecord().get('CurrencyIsoCode'));
        }

        //get account payable Fields that are added to the account payable fields to clone fieldset
        apFields = DeepCloneFieldSetService.getCloneableFields(String.valueOf(Account_Payable__c.SObjectType),PACKAGE_QUALIFIER + 'Payable_fields_to_Clone');
        //get account payable line Fields that are added to the account payable line fields to clone fieldset
        apLineFields = DeepCloneFieldSetService.getCloneableFields(String.valueOf(Account_Payable_Line__c.SObjectType),PACKAGE_QUALIFIER + 'Payable_Line_fields_to_Clone');
        // keep a copy of apline fields
        tempApLineFields.addAll(apLineFields);

        originalAcctPayable = queryAccountPayable();
        tempPayable.Vendor__c = originalAcctPayable.Vendor__c;
        if (tempPayable.Vendor__c == NULL) {
            tempPayable.Due_Date__c = getCalculatedDueDate();
        }
    }
    private Date getCalculatedDueDate() {
        return tempPayable.Date__c.addDays(originalAcctPayable.Date__c.daysBetween(originalAcctPayable.Due_Date__c));
    }

    // cloneWithlines()
    public PageReference cloneWithlines() {
        // setup the save point for rollback
        isError = false;
        Savepoint sp = Database.setSavepoint();

        Accounting_Period__c currentAccountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(tempPayable.Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Account_Payable__c.SObjectType);

        if (currentAccountingPeriod == NULL) {
            isError = true;
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.SEVERITY.ERROR,
                String.format(NO_OPEN_PERIOD_ERROR_MESSAGE, new List<String>{(tempPayable.Date__c).format()})
            ));
            return NULL;
        }

        try {
            cloneAcctPayable = originalAcctPayable.clone(false);

            cloneAcctPayable.Date__c = tempPayable.Date__c;
            cloneAcctPayable.Due_Date__c = tempPayable.Due_Date__c;
            cloneAcctPayable.Payee_Reference__c = apName + ' ' + System.now().format();

            if (isMultiCurrencyEnabled) {
                cloneAcctPayable.put('CurrencyIsoCode', tempPayable.get('CurrencyIsoCode'));
            }

            apFields.remove('Name');

            // Insert AccountPayable
            SFDCSecurityUtils.insertCheckCRUDAndFLS(
                    cloneAcctPayable, 
                    new List<String>(apFields));

            newAPLines = new List<Account_Payable_Line__c>();
            for (Account_Payable_Line__c apl : queryAccountPayableLines()) {
                Account_Payable_Line__c newApl = apl.clone(false);
                newApl.Account_Payable__c = cloneAcctPayable.Id;
                newApl.Date__c = tempPayable.Date__c;
                
                // FS-9320
                calculateQuantityCostTotal(newApl);
                if (makeCreditMemo) {
                    convertToCreditMemo(newApl);
                }

                newAPLines.add(newApl);
            }

            // Insert the list of AccountPayable Lines
            SFDCSecurityUtils.insertCheckCRUDAndFLS(newAPLines, new List<String>(apLineFields));

            theNewPayableId = cloneAcctPayable.Id;
        }
        catch (Exception e) {
            Database.rollback(sp);
            isError = true;
            ApexPages.addMessages(e);
            return NULL;
        }

        return new PageReference(FinancialSuiteUtils.getRedirectToSObjectURL(theNewPayableId, Account_Payable__c.SObjectType, true));
    }

    private void calculateQuantityCostTotal(Account_Payable_Line__c line) {
        Boolean cloneQuantity = tempApLineFields.contains(PACKAGE_QUALIFIER + 'Quantity__c');
        Boolean cloneUnitCost = tempApLineFields.contains(PACKAGE_QUALIFIER + 'Unit_Cost__c');
        Boolean cloneTotal = tempApLineFields.contains(PACKAGE_QUALIFIER + 'Amount__c');

        line.Quantity__c = cloneQuantity ? line.Quantity__c : 1;
        line.Unit_Cost__c = cloneUnitCost ? line.Unit_Cost__c : 0;
        line.Amount__c = cloneTotal ? line.Sub_Total__c : 0; // Amount will be have tax added in trigger if applicable


        if ((cloneQuantity && !cloneUnitCost && cloneTotal) || (!cloneQuantity && !cloneUnitCost && cloneTotal)) {
            line.Unit_Cost__c = line.Quantity__c == 0 ? 0 : line.Sub_Total__c / line.Quantity__c;
        }
    }

    private void convertToCreditMemo(Account_Payable_Line__c line) {
        if (line.Amount__c <= 0) {
            return;
        }
        if (AccountingSettingsHandler.isCreditMemoDefaultQuantity()) {
            line.Quantity__c *= -1;
        } else if (AccountingSettingsHandler.isCreditMemoDefaultAmount()) {
            line.Unit_Cost__c *= -1;
        }
        line.Amount__c *= -1;        
    }

    private Account_Payable__c queryAccountPayable() {
        //=== Build SOQL query with CRUD checks ===
        //add required fields to the list regardless of what is included in fieldset
        apFields.add(PACKAGE_QUALIFIER + 'Vendor__c');
        apFields.add(PACKAGE_QUALIFIER + 'Contact__c');
        apFields.add(PACKAGE_QUALIFIER + 'Employee__c');
        apFields.add(PACKAGE_QUALIFIER + 'Date__c');
        apFields.add(PACKAGE_QUALIFIER + 'Due_Date__c');

        //Add query condition
        String queryCondition = 'Id = :apId LIMIT 1';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(new List<String>(apFields))
            .setCondition(queryCondition);

        return (Account_Payable__c) Database.query(theQuery.toSOQL());
    }

    private List<Account_Payable_Line__c> queryAccountPayableLines() {
        //=== Build SOQL query with CRUD checks ===

        List<String> fields = new List<String>(apLineFields);
        // add non-clonable field used for calculations
        fields.add(PACKAGE_QUALIFIER+'Sub_Total__c');

        //Add query condition
        String queryCondition = 'Account_Payable__c = :apId ORDER BY Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(new List<String>(fields))
            .setCondition(queryCondition);

        return (List<Account_Payable_Line__c>) Database.query(theQuery.toSOQL());
    }

}