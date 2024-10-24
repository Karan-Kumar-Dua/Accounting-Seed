//======================================================================================================
// The only caller of this batchable class is the X1099FileController controller extension class.
// Read and FLS checks are performed on the Account and Contact fields in the caller class
// BEFORE this class is instantiated. This was reviewed by Nitin Arya of the Security Review Team
// Please communicate with him BEFORE summarily failing this class with regard to the Security Review.
//======================================================================================================

public without sharing class X1099File2Batch implements Database.Batchable<SObject>, Database.Stateful {

    public String selectedYearName {get; set;}

    public String selectedx1099FormTypeId {get; set;}
    public List<string> formCategoryIDs {get;set;}
    
    @TestVisible
    private static final String NON_CATEGORIZED_PAYMENTS = Label.COMMON_NON_CATEGORIZED_PAYMENTS;

    private Map<Id, Map<String, Map<String, Decimal>>> payeeIdToDisbursementAmountByCategory;
    private List<Form_Category__mdt> formCategoriesList;
    private Form_Type__mdt x1099FormType;
    private string x1099ReportingISOCode {get;set;}

    @TestVisible
    private static Map<Id, Map<String, Map<String, Decimal>>> testPayeeIdToDisbursementAmountByCategory;

    @TestVisible
    private static Boolean isSendEmptyEmail;
    @TestVisible
    private static Boolean isSendFileEmail;

    private Id ledgerId;
    private Date firstDayOfTheSelectedYear;
    private Date lastDayOfTheSelectedYear;

    private Ledger__c ledger;
    private String queryString;
    private static final Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

    private final List<String> COLUMNS_HEADERS {
        get {
            if (COLUMNS_HEADERS == NULL) {
                COLUMNS_HEADERS = new List<String>{
                    'Ledger',
                    'Source Record Currency',
                    '1099 Reporting Currency',
                    '1099 Year',
                    '1099 Form Type',
                    'Recipient Identification Number',
                    'Recipient First Name',
                    'Recipient Last Name',
                    'Recipient Name If Company',
                    'Recipient Address 1',
                    'Recipient City',
                    'Recipient State',
                    'Recipient Zip'
                };

                for(Form_Category__mdt formCategory : formCategoriesList){
                    COLUMNS_HEADERS.add(formCategory.Label);
                }

                COLUMNS_HEADERS.add(NON_CATEGORIZED_PAYMENTS);   
            }
            return COLUMNS_HEADERS;
        }
        set;
    }

    public X1099File2Batch(String selectedYearName, Id ledgerId, Id x1099FormTypeId) {
        this.selectedYearName = selectedYearName;
        this.selectedX1099FormTypeId = x1099FormTypeId;
        this.ledgerId = ledgerId;
        isSendEmptyEmail = false;
        isSendFileEmail = false;
       
        firstDayOfTheSelectedYear = Date.newInstance(Integer.valueOf(selectedYearName), 1, 1);
        lastDayOfTheSelectedYear = Date.newInstance(Integer.valueOf(selectedYearName), 12, 31);
        ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);

        this.x1099ReportingISOCode = isMultiCurrencyEnabled ? (String)ledger.get('CurrencyIsoCode'): MultiCurrencyHandler.CORPORATE_CURRENCY; 
        formCategoriesList = X1099InfoHelper.getFormCategoriesByFormType(x1099FormTypeId);
        List<String> formCategoryIDs = new List<String>();
        for (Form_Category__mdt formCategory : formCategoriesList) {
            formCategoryIDs.add(formCategory.Id);
        }
        this.formCategoryIDs = formCategoryIDs;
        payeeIdToDisbursementAmountByCategory = new Map<Id, Map<String, Map<String, Decimal>>>();
    //where form category.type matches or is blank
        queryString = 'SELECT Id, Amount__c, Ledger_Amount__c, Vendor__c, Contact__c, Form_Category_ID__c '
                + (isMultiCurrencyEnabled ? ', CurrencyIsoCode ' : '')
                + 'FROM Cash_Disbursement__c '
                + 'WHERE (Vendor__r.X1099_Vendor__c = true OR Contact__r.X1099_Vendor__c = true) '
                + 'AND (Form_Category_ID__c in :formCategoryIDs OR Form_Category_ID__c = null) '
                + 'AND Disbursement_Date__c >= :firstDayOfTheSelectedYear '
                + 'AND Disbursement_Date__c <= :lastDayOfTheSelectedYear '
                + 'AND Payment_Status__c != \'Void\' '
                + 'AND (Ledger__c = :ledgerId';
        queryString += LedgerHandler.isLedgerEqualLegacyLedger(ledgerId) ? ' OR Ledger__c = NULL)' : ')';
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(queryString);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        for (Cash_Disbursement__c eachCD : (List<Cash_Disbursement__c>) scope) {
            if (eachCD.Vendor__c != NULL) {
                resolvePayeeToDisbursementAmount(eachCD.Vendor__c, eachCD);
            }
            else if (eachCD.Contact__c != NULL) {
                resolvePayeeToDisbursementAmount(eachCD.Contact__c, eachCD);
            }
        }
    }

    private void resolvePayeeToDisbursementAmount(Id payeeId, Cash_Disbursement__c cd) {
        //if calculation for this payee was already started
        String isoCodeKey = getCurrencyIsoCode(cd);

        Decimal cashDisbAmount = (isMultiCurrencyEnabled) ? cd.Ledger_Amount__c: cd.Amount__c;
        string formCategoryID = cd.Form_Category_ID__c == null? NON_CATEGORIZED_PAYMENTS: cd.Form_Category_ID__c;
        if (payeeIdToDisbursementAmountByCategory.containsKey(payeeId)) {
            Map<String, Map<String, Decimal>> isoCodeToDisbursementAmount = payeeIdToDisbursementAmountByCategory.get(payeeId);
            Map<String, Decimal> categoryToDisbursementAmount = new Map<String, Decimal>();

            //if collection with ISO code already exists in collection
            if (isoCodeToDisbursementAmount.containsKey(isoCodeKey)) {
                //get map of categories and amounts
                categoryToDisbursementAmount = isoCodeToDisbursementAmount.get(isoCodeKey);
                if(categoryToDisbursementAmount.containsKey(formCategoryID)) {
                    Decimal incrementedAmount = categoryToDisbursementAmount.get(formCategoryID) + cashDisbAmount;
                    categoryToDisbursementAmount.put(formCategoryID, incrementedAmount);
                } else {
                    categoryToDisbursementAmount.put(formCategoryID, cashDisbAmount);
                }
            } 
            else {
                categoryToDisbursementAmount.put(cd.Form_Category_ID__c, cashDisbAmount);
                isoCodeToDisbursementAmount.put(isoCodeKey,categoryToDisbursementAmount);
            }
            payeeIdToDisbursementAmountByCategory.put(payeeId, isoCodeToDisbursementAmount);
        }
        else {//if it is first time when we start calculation for this payee
            Decimal initialAmount = (payeeId != NULL) ? cashDisbAmount: 0;

            Map<String, Decimal> categoryToDisbursementAmount = new Map<String, Decimal>();
            categoryToDisbursementAmount.put(formCategoryID, initialAmount);

            Map<String, Map<String, Decimal>> isoCodeToDisbursementAmount = new Map<String, Map<String, Decimal>>();
            isoCodeToDisbursementAmount.put(isoCodeKey,categoryToDisbursementAmount);
            payeeIdToDisbursementAmountByCategory.put(payeeId, isoCodeToDisbursementAmount);
        }
    }

    private String getCurrencyIsoCode(Cash_Disbursement__c cd) {
        return isMultiCurrencyEnabled ? (String) cd.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
    }

    public void finish(Database.BatchableContext bc) {
        Set<Id> setPayeeIdsForFile = new Set<Id>();

        for (Id payeeId : payeeIdToDisbursementAmountByCategory.keySet()) {
            setPayeeIdsForFile.add(payeeId);
        }

        if (!setPayeeIdsForFile.isEmpty()) {
            createFileAndSendByEmail(setPayeeIdsForFile);
        }
        else {
            sendEmptyEmail();
        }
        testPayeeIdToDisbursementAmountByCategory = payeeIdToDisbursementAmountByCategory;
    }

    //utility methods
    private void sendEmptyEmail() {
        isSendEmptyEmail = true;
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSubject(Label.COMMON_ACCOUNTING_SEED_FINANCIAL_SUITE + x1099FormType().Label + Label.COMMON_FILE);
        mail.setPlainTextBody(
            Label.INF_NO_DATE_MEETING_REQUIREMENTS + '\n' + Label.COMMON_1099_YEAR +
                selectedYearName +
                '\n' + Label.COMMON_1099_FORM_TYPE +
                x1099FormType().Label +
                '\n' + Label.COMMON_LEDGER + ': '
                + ledger.Name
        );
        //sending email with an attachment
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
    }

    private void createFileAndSendByEmail(Set<Id> setPayeeIdsForFile) {
        isSendFileEmail = true;
        //check the limits
        if (!FinancialSuiteUtils.canSendEmail()) {
            return;
        }
        //build file attachment
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('accounting_seed_financial_suite_' + x1099FormType().Label + '.csv');
        efa.setBody(createFile(getCsvFileContent(setPayeeIdsForFile)));
        //build email message
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSubject(Label.COMMON_ACCOUNTING_SEED_FINANCIAL_SUITE + x1099formType().Label + Label.COMMON_FILE);
        mail.setPlainTextBody(Label.COMMON_THE + x1099formType().Label + Label.COMMON_FILE_IS_ATTACHED);
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{efa});
        //sending email with an attachment
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
    }

    private String getCsvFileContent(Set<Id> setPayeeIdsForFile) {
        List<RecipientWrapper> recipients = new List<RecipientWrapper>();
        String csvRow = '';

        List<SObject> accounts = new List<SObject>((SObject[])[SELECT Id,
                Name,
                Taxpayer_Identification_Number__c,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                Default_1099_Box__c
        FROM Account
        WHERE Id IN :setPayeeIdsForFile]);

        List<SObject> contacts = new List<SObject>((SObject[])[SELECT  Id,
                Name,
                FirstName,
                LastName,
                Taxpayer_Identification_Number__c,
                MailingStreet,
                MailingCity,
                MailingState,
                MailingPostalCode,
                Default_1099_Box__c
        FROM Contact
        WHERE Id IN :setPayeeIdsForFile]);

        recipients.addAll(createRecipientList(accounts));
        recipients.addAll(createRecipientList(contacts));
        recipients.sort();

        //build file content
        for (RecipientWrapper recipient : recipients) {
            csvRow = csvRow +
                '"' + ledger.Name + '",' +
                '"' + recipient.isoCode + '",' +
                '"' + x1099ReportingISOCode + '",' + 
                '"' + selectedYearName + '",' +
                '"' + x1099formType().Type__c + '",' +
                '"' + recipient.recIdNumber + '",' +
                '"' + recipient.recFirstName + '",' +
                '"' + recipient.recLastName + '",' +
                '"' + recipient.recCompanyName + '",' +
                '"' + recipient.recStreet + '",' +
                '"' + recipient.recCity + '",' +
                '"' + recipient.recState + '",' +
                '"' + recipient.recZip + '",';

                string categoryAmounts = '';
                for(Form_Category__mdt formCategory : formCategoriesList){
                    if(recipient.CategoryAmounts.containsKey(formCategory.Id)){
                        string Amount = formatCategoryValue(recipient.CategoryAmounts.get(formCategory.Id));
                        categoryAmounts +=  '"' + Amount + '",';
                    }else{
                        categoryAmounts +=  '"' + '' + '",';
                    }
                }  
                csvRow = csvRow + categoryAmounts;  

                string nonCategoryAmount = '';
                if(recipient.CategoryAmounts.containsKey(NON_CATEGORIZED_PAYMENTS)){
                    decimal Amount = recipient.CategoryAmounts.get(NON_CATEGORIZED_PAYMENTS).setScale(2);
                    nonCategoryAmount  =  '"' + Amount + '",';
                }
                csvRow = csvRow + nonCategoryAmount.removeEnd(',');  
                csvRow = csvRow + '\r\n';
        }

        return csvRow;
    }

    private List<RecipientWrapper> createRecipientList(List<SObject> objects) {
        List<RecipientWrapper> recipients = new List<RecipientWrapper>();
        for (SObject obj : objects) {
            for (String isoCode : payeeIdToDisbursementAmountByCategory.get(obj.Id).keySet()) {
                    RecipientWrapper tempWrappedRec = new RecipientWrapper(obj);
                    tempWrappedRec.isoCode = isoCode;
                    tempWrappedRec.CategoryAmounts = payeeIdToDisbursementAmountByCategory.get(obj.Id).get(isoCode);
                    recipients.add(tempWrappedRec);
            }
        }
        return recipients;
    }

    private String getHeader() {
        String header = '';
        for (String columnName : COLUMNS_HEADERS) {
            header += columnName + ', ';
        }
        header = header.substring(0, header.length() - 2);
        return header;
    }

    private Blob createFile(String csvFileContent) {
        return Blob.valueOf(getHeader() + '\r\n' + csvFileContent);
    }

    private Form_Type__mdt x1099FormType() {
        if (x1099FormType == NULL) {
            try {
                x1099FormType = [SELECT Id, Label, Type__c FROM Form_Type__mdt WHERE Id = :selectedX1099FormTypeId];
            }
            catch (Exception ex) {

            }
        }
        
        return x1099FormType;
    }

    private String formatCategoryValue(Decimal categoryValue) {
        if (categoryValue != NULL && categoryValue.scale() < 2) {
            categoryValue = categoryValue.setScale(2);
        }
        return String.valueOf(categoryValue);
    }


    public class InvalidTypeException extends Exception {}

    public with sharing class RecipientWrapper implements Comparable {
        public SObject recipient {get; set;}
        public String recIdNumber {get; set;}
        public String recName {get; set;}
        public String recFirstName {get; set;}
        public String recLastName {get; set;}
        public String recCompanyName {get; set;}
        public String recStreet {get; set;}
        public String recCity {get; set;}
        public String recState {get; set;}
        public String recZip {get; set;}
        public String isoCode {get; set;}
        public Decimal recAmount {get; set;}
        public Map<String, Decimal> CategoryAmounts;

        public RecipientWrapper(SObject obj) {
            recipient = obj;
            recName = (String) recipient.get('Name') != NULL ? (String) recipient.get('Name') : '';
            recCompanyName = '';
            recFirstName = '';
            recLastName = '';
            recIdNumber = (String) recipient.get('Taxpayer_Identification_Number__c') != NULL ? (String) recipient.get('Taxpayer_Identification_Number__c') : '';

            if (obj.getSObjectType() == Schema.Account.getSObjectType()) {
                mapAddress('Billing');
                recCompanyName = (String) recipient.get('Name') != NULL ? (String) recipient.get('Name') : '';
            }
            else if (obj.getSObjectType() == Schema.Contact.getSObjectType()) {
                mapAddress('Mailing');
                recFirstName = (String) recipient.get('FirstName') != NULL ? (String) recipient.get('FirstName') : '';
                recLastName = (String) recipient.get('LastName') != NULL ? (String) recipient.get('LastName') : '';
            }
            else {
                throw new InvalidTypeException(Label.INF_USE_ACCOUNT_OR_CONTACT_SOBJECT);
            }
        }

        private void mapAddress(String prefix) {
            recStreet = (String) recipient.get(prefix + 'Street') != NULL ? (String) recipient.get(prefix + 'Street') : '';
            recCity = (String) recipient.get(prefix + 'City') != NULL ? (String) recipient.get(prefix + 'City') : '';
            recState = (String) recipient.get(prefix + 'State') != NULL ? (String) recipient.get(prefix + 'State') : '';
            recZip = (String) recipient.get(prefix + 'PostalCode') != NULL ? (String) recipient.get(prefix + 'PostalCode') : '';
        }

        public Integer compareTo(Object objToCompare) {
            return this.recName.compareTo(((RecipientWrapper)objToCompare).recName);
        }

    }
}