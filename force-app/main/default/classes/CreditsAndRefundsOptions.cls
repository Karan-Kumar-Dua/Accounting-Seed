global with sharing class CreditsAndRefundsOptions {

    @TestVisible
    private static final String ERR_INVALID_SRC_DOC_TYPE =  Label.ERR_INVALID_SRC_DOC_TYPE ;

    @TestVisible
    private static final String CASH_RECEIPT_REFUND_REFERENCE_MESSAGE = Label.CASH_RECEIPT_REFUND_REFERENCE_MESSAGE;

    @TestVisible
    private static final String CREDIT_MEMO_REFUND_REFERENCE_MESSAGE = Label.CREDIT_MEMO_REFUND_REFERENCE_MESSAGE;

    
    
    //global variables
    @AuraEnabled
    global Id sourceRecordId;

    @AuraEnabled
    global Decimal refundAmount;
    
    @AuraEnabled
    global Date refundDate;
    
    @AuraEnabled
    global String paymentType;
    
    @AuraEnabled
    global Id bankAccount;
    
    @AuraEnabled
    global String reference;
    
    @AuraEnabled
    global String memo;

    @AuraEnabled
    global Id project;

    @AuraEnabled
    global Id projectTask;

    @AuraEnabled
    global Id gla1;

    @AuraEnabled
    global Id gla2;

    @AuraEnabled
    global Id gla3;

    @AuraEnabled
    global Id gla4;

    
    @AuraEnabled
    global Id cashFlowCategory;

    //global final variables derived from source records - used for setting defaults on credit memos and cash receipts
    global Id cashReceiptId;
    global Id billingId;
    //defaults for new credit memo or cash receipt
    global final Id customer;
    global final Id ledger;
    global final String currencyIsoCode;
    global final Decimal currencyConversionRate;
    global final Id creditGLAccount;
    //used for validations
    global final Date sourceRecordDate;
    global final Decimal sourceRecordBalance;

    public Boolean isSourceCreditMemo = false;

    public transient Map<String, Object> additionalParams;

    global CreditsAndRefundsOptions(Id sourceRecordId){
        
        Schema.SObjectType sObjectType = sourceRecordId.getSObjectType();
        if(sObjectType == Schema.Billing__c.sObjectType){
            BillingModel sourceCreditMemo = Billing.retrieve(sourceRecordId);
            //API defaults
            this.refundAmount = sourceCreditMemo.bill.Balance__c;
            this.billingId = sourceCreditMemo.bill.Id;
            
            String referenceDefault = String.format(
                CREDIT_MEMO_REFUND_REFERENCE_MESSAGE,
                new List<String>{sourceCreditMemo.bill.Name}
            );

            this.reference = referenceDefault;

            //used for validation to determine if the originating billing is a credit memo
            this.isSourceCreditMemo = sourceCreditMemo.bill.Balance__c < 0 ? true : false;
            
            //final variables - used for validations and creation of records            
            this.customer = sourceCreditMemo.bill.Customer__c;
            this.ledger = sourceCreditMemo.bill.Ledger__c;
            this.sourceRecordBalance = sourceCreditMemo.bill.Balance__c;
            this.sourceRecordDate = sourceCreditMemo.bill.Date__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled){
                this.currencyIsoCode = (String) sourceCreditMemo.bill.get('CurrencyIsoCode');
                this.currencyConversionRate = sourceCreditMemo.bill.Currency_Conversion_Rate__c;
            }

        } else if(sObjectType == Schema.Cash_Receipt__c.sObjectType){
            Cash_Receipt__c sourceCashReceipt = queryCashReceipt(sourceRecordId);
            //API defaults
            this.refundAmount = sourceCashReceipt.Balance__c;
            this.bankAccount = sourceCashReceipt.Bank_Account__c;
            this.paymentType = sourceCashReceipt.Payment_Type__c;

            String referenceDefault = String.format(
                CASH_RECEIPT_REFUND_REFERENCE_MESSAGE,
                new List<String>{sourceCashReceipt.Name}
            );
            this.reference = referenceDefault;
            this.customer = sourceCashReceipt.Account__c;

            //final variables - used for validations and creation of records
            this.cashReceiptId = sourceCashReceipt.Id;
            this.ledger = sourceCashReceipt.Ledger__c;
            this.creditGLAccount = sourceCashReceipt.Credit_GL_Account__c;
            this.sourceRecordBalance = sourceCashReceipt.Balance__c;
            this.sourceRecordDate = sourceCashReceipt.Receipt_Date__c;
            this.project = sourceCashReceipt.Project__c;
            this.projectTask = sourceCashReceipt.Project_Task__c;
            this.gla1 = sourceCashReceipt.GL_Account_Variable_1__c;
            this.gla2 = sourceCashReceipt.GL_Account_Variable_2__c;
            this.gla3 = sourceCashReceipt.GL_Account_Variable_3__c;
            this.gla4 = sourceCashReceipt.GL_Account_Variable_4__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled){
                this.currencyIsoCode = (String) sourceCashReceipt.get('CurrencyIsoCode');
                this.currencyConversionRate = sourceCashReceipt.Currency_Conversion_Rate__c;
            }

        } else {
            throw new CreditsAndRefunds.CreditsAndRefundsException(ERR_INVALID_SRC_DOC_TYPE);
        }

        this.refundDate = Date.today();
        this.sourceRecordId = sourceRecordId;
    }

    private Cash_Receipt__c queryCashReceipt(Id sourceRecordId){
        List<Cash_Receipt__c> result = new List<Cash_Receipt__c>();

        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account__c',
            'Balance__c',
            'Bank_Account__c',
            'Ledger__c',
            'Credit_GL_Account__c',
            'Receipt_Date__c',
            'Payment_Type__c',
            'Cash_Flow_Category__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled){
            queryFields.add('CurrencyIsoCode');
            queryFields.add('Currency_Conversion_Rate__c');
        }

        String queryCondition;
        queryCondition = 'Id = :sourceRecordId';
    

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());
        return result[0];
    }

}