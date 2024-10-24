global with sharing class CreditsAndRefunds {
    
    global class CreditsAndRefundsException extends Exception{}
    
 
    @TestVisible
    private APIServiceContext.APIServiceEntry serviceEntry;
    
    @TestVisible
    private ServiceResult serviceResult;

    private BillingModel billingModel;
    private Id billingToCreditId;
    private Date applyDate;
    private Decimal applyAmount;
    private Accounting_Period__c acctPeriodForApply;
    private CreditsAndRefundsOptions options;
    @TestVisible
    private static final String PAYMENT_TYPE_CHECK = 'Check';


    @TestVisible
    private static final String NO_INPUT_DATA = Label.ERR_NO_INPUT_DATA;
    
    @TestVisible
    private static final String ERR_REFUND_APPLIED_DATE_INVALID = Label.ERR_REFUND_APPLIED_DATE_INVALID;

    @TestVisible
    private static final String ERR_REFUND_NEGATIVE_BALANCE = Label.ERR_REFUND_NEGATIVE_BALANCE;

    @TestVisible
    private static final String ERR_REFUND_AMOUNT_GREATER_BALANCE = Label.ERR_REFUND_AMOUNT_GREATER_BALANCE ;

    @TestVisible
    private static final String ERR_REFUND_REFUND_DATE_INVALID = Label.ERR_REFUND_REFUND_DATE_INVALID;

    @TestVisible
    private static final String ERR_REFUND_INVALID_TYPE = Label.ERR_REFUND_INVALID_TYPE;

    @TestVisible
    private static final String ERR_REFUND_AMOUNT_GREATER_CM_BALANCE = Label.ERR_REFUND_AMOUNT_GREATER_CM_BALANCE ;

    @TestVisible
    private static final String ERR_REFUND_LESS_THAN_ZERO = Label.ERR_REFUND_LESS_THAN_ZERO;

    @TestVisible
    private static final String ERR_REFUND_REQUIRED_BANK_ACCOUNT = Label.ERR_REFUND_REQUIRED_BANK_ACCOUNT;

    @TestVisible
    private static final String ERR_REFUND_BANK_ACCOUNT_MUST_ENABLED = Label.ERR_REFUND_BANK_ACCOUNT_MUST_ENABLED;


    public CreditsAndRefunds() {
        serviceResult = new ServiceResult();
        serviceEntry = new APIServiceContext.APIServiceEntry();
        billingModel = new BillingModel();
    }

    public CreditsAndRefunds(Id billingId) {
        this();
        this.billingToCreditId = billingId;
    }

    public CreditsAndRefunds(Id billingId, Date applyDate, Decimal applyAmount, BillingModel billingModel) {
        this();
        this.billingToCreditId = billingId;
        this.applyDate = applyDate;
        this.applyAmount = applyAmount;
        this.billingModel = billingModel;
    }

    public CreditsAndRefunds(CreditsAndRefundsOptions options) {
        this();
        this.options = options;
     }

    //=========================   GLOBAL ENTRY POINTS   ===========================================

    /* 
    * This method clones the passed in Billing and all associated Billing Lines into a new 
    * BillingModel which is returned but not committed to the database.  The rate on the lines
    * is multiplied by -1 to make the new Billing a Credit Memo. 
    */
    global static BillingModel getCreditMemoFromBilling(Id BillingId){
        BillingModel retrieveResult;
        CreditsAndRefunds service = new CreditsAndRefunds(BillingId);
        ServiceResult sr = APIServiceContext.validateServiceContext(service.serviceEntry);

        if (sr.isSuccess) {
            retrieveResult = service.createCreditMemoFromBilling();
        }else {
            throw new CreditsAndRefundsException(String.join(sr.errors, ','));
        }

        return retrieveResult;
    }

    /* NOT IMPLEMENTED*/
    global static ServiceResult applyCreditMemo(Id BillingId, Date applyDate, Decimal applyAmount, BillingModel billingModel) {
        return null;
    }

    /* 
    * This method is designed to work from a Cash Receipt defined in the options parameter.  It creates a 
    * funding Credit Memo with a single line equal to the the options.refundAmount * -1 to make it a Credit Memo and
    * creates a BillingCashReceipt record to apply the new funding Credit Memo to the Cash Receipt
    */
    global static ServiceResult createAndApplyFundingCreditMemo(CreditsAndRefundsOptions options){
        ServiceResult serviceResult;
       
        try {
            CreditsAndRefunds svc = new CreditsAndRefunds(options);
            ServiceResult validationResult = APIServiceContext.validateServiceContext(svc.serviceEntry);
        
            if (validationResult.isSuccess) {
                serviceResult = svc.createAndApplyFundingCreditMemo();
            } 
        } catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
       
        return serviceResult;
    }

    /* 
    * This method is designed to work from a Credit Memo defined in the options parameter.  It creates a 
    * negative Cash Receipt equal to the options.refundAmount and creates a BillingCashReceipt record to apply
    * the funding Credit Memo to the new negative Cash Receipt
    */
    global static ServiceResult createAndApplyRefundCashReceipt(CreditsAndRefundsOptions options){
        ServiceResult serviceResult;
        try {
            CreditsAndRefunds svc = new CreditsAndRefunds(options);
            ServiceResult validationResult = APIServiceContext.validateServiceContext(svc.serviceEntry);

            if (validationResult.isSuccess) {
                serviceResult = svc.createAndApplyRefundCashReceipt();
            }
        } catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }

    /* 
    * This method is designed to work from a Cash Receipt defined in the options parameter.
    * It creates a funding Credit Memo with a single line equal to the the options.refundAmount * -1 
    * to make it a Credit Memo and creates a BillingCashReceipt record to apply the new 
    * funding Credit Memo to the Cash Receipt.
    *
    * Then it creates a negative Cash Receipt equal to the options.refundAmount and creates 
    * a BillingCashReceipt record to apply the new funding Credit Memo to the new negative Cash Receipt
    */
    global static ServiceResult createRefundForCashReceipt(CreditsAndRefundsOptions options){
        ServiceResult serviceResult;
        try {
            CreditsAndRefunds svc = new CreditsAndRefunds(options);
            ServiceResult validationResult = APIServiceContext.validateServiceContext(svc.serviceEntry);

            if (validationResult.isSuccess) {
                serviceResult = svc.createRefundForCashReceipt();
            }
        } catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return serviceResult;
    }
    


    //=========================   PUBLIC METHODS   ============================================   
    public static BillingModel getCreditMemoFromBilling(Id billingId, Set<String> includeBillingLineFields){
        BillingModel retrieveResult;
        CreditsAndRefunds service = new CreditsAndRefunds(billingId);
        ServiceResult sr = APIServiceContext.validateServiceContext(service.serviceEntry);

        if (sr.isSuccess) {
            retrieveResult = service.createCreditMemoFromBilling(includeBillingLineFields);
        }

        return retrieveResult;
    }

    //============================================================================================

    private ServiceResult createAndApplyFundingCreditMemo(){
        Savepoint sp = Database.setSavepoint();

        if (validateOptions() && validateFundingCreditMemoOptions()) {
            try {
                serviceResult = Billing.create(createCreditMemoFromOptions());
                if(serviceResult.isSuccess){   
                    //set the new billing ID used for BCR record
                    options.billingId = serviceResult.data;
                     ServiceResult bcrService = createBillingCashReceipt(true);
                     //if there is an error with the BCR return that service result otherwise return the billing
                     if(bcrService.isSuccess){
                        postFundingCreditMemoFuture(options.billingId);
                     } else {
                        Database.rollback(sp);
                        serviceResult = bcrService;
                     }
                } else{
                    Database.rollback(sp);
                }
            }catch(Exception ex){
                Database.rollback(sp);
                serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
            }
        }

        if(!serviceResult.isSuccess){
            Database.rollback(sp);
        }
        
        return serviceResult;
    }

    private ServiceResult createAndApplyRefundCashReceipt(){
        Savepoint sp = Database.setSavepoint();
        
        if (validateOptions() && validateRefundCashReceiptOptions()){
            try{
                //set refund amount to positive, negating it will be handled when needed
                options.refundAmount = math.abs(options.refundAmount);

                //create cash receipt
                serviceResult = createCashReceiptFromOptions();
                if(serviceResult.isSuccess){
                    options.cashReceiptId = serviceResult.data;
                    //apply to credit memo via a billing cash receipt record
                    ServiceResult bcrService = createBillingCashReceipt(false);
                    if(!bcrService.isSuccess){
                        Database.rollback(sp);
                        serviceResult = bcrService;
                    }
                }else{
                    Database.rollback(sp);
                }
            }catch(Exception ex){
                Database.rollback(sp);
                serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
            }
        }
       
        return serviceResult;
    }


    private ServiceResult createRefundForCashReceipt(){
        Savepoint sp = Database.setSavepoint();
         serviceResult = createAndApplyFundingCreditMemo();
         if(serviceResult.isSuccess){
            //set the Billing ID 
            options.billingId = serviceResult.data;
            //set refund amount to positive, negating it will be handled when needed
            options.refundAmount = math.abs(options.refundAmount);
            options.isSourceCreditMemo = true;

            serviceResult = createAndApplyRefundCashReceipt();
            if(serviceResult.isSuccess){
                postFundingCreditMemoFuture(options.billingId);
            }else{
                Database.rollback(sp);
            }
         }else{
            Database.rollback(sp);
         }

        return serviceResult;
    }


    private BillingModel createCreditMemoFromBilling() {
        return createCreditMemoFromBilling(new Set<String>());
    }

    private BillingModel createCreditMemoFromBilling(Set<String> includeBillingLineFields) {
        billingModel = new BillingModel();
        billingModel = Billing.retrieve(billingToCreditId, true, includeBillingLineFields);
        
        billingModel.bill = billingModel.bill.clone(false);
        billingModel.bill.Accounting_Period__c = null;

        list<Billing_Line__c> clonedBillingLines = new list<Billing_Line__c>();
        for(Billing_Line__c bl : billingModel.billLines){
            Billing_Line__c clonedBL = bl.clone(false);
            clonedBL.Rate__c = AccountingSettingsHandler.isCreditMemoDefaultAmount() ? bl.Rate__c * -1 : bl.Rate__c;
            clonedBL.Hours_Units__c = AccountingSettingsHandler.isCreditMemoDefaultQuantity() ? bl.Hours_Units__c * -1 : bl.Hours_Units__c;
            clonedBillingLines.add(clonedBL);
        }
        billingModel.billLines = clonedBillingLines;

        return billingModel;
    }

    private BillingModel createCreditMemoFromOptions(){
        BillingModel billingModel = new BillingModel();
        
        Billing__c creditMemo = new Billing__c();      
        creditMemo.Customer__c = options.customer;
        creditMemo.Date__c = options.refundDate;
        creditMemo.Ledger__c = options.ledger;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled){
            creditMemo.put('CurrencyIsoCode', options.CurrencyIsoCode);
            creditMemo.Currency_Conversion_Rate__c = options.currencyConversionRate;
        }

        billingModel.bill = creditMemo;

        List<Billing_Line__c> creditMemoLines = new List<Billing_Line__c>();
        Billing_Line__c creditMemoLine = new Billing_Line__c();
        creditMemoLine.Hours_Units__c = 1;
        creditMemoLine.Rate__c = options.refundAmount * -1;
        creditMemoLine.Revenue_GL_Account__c = options.creditGLAccount;
        creditMemoLines.add(creditMemoLine);

        billingModel.billLines = creditMemoLines;

        return billingModel;
    }

    private ServiceResult createCashReceiptFromOptions(){
        ServiceResult result;
        
        try{
            Cash_Receipt__c cashReceipt = new Cash_Receipt__c (
                Account__c = options.customer,
                Amount__c =  options.refundAmount * -1,
                Ledger__c = options.ledger,
                Bank_Account__c = options.bankAccount,
                Purpose__c = 'Customer Refund',
                Receipt_Date__c = options.refundDate,
                Cash_Flow_Category__c = options.cashFlowCategory,
                Memo__c = options.memo,
                Payment_Reference__c = options.reference,
                Project__c = options.project,
                Project_Task__c = options.projectTask,
                GL_Account_Variable_1__c = options.gla1,
                GL_Account_Variable_2__c = options.gla2,
                GL_Account_Variable_3__c = options.gla3,
                GL_Account_Variable_4__c = options.gla4
            );
            if (options.additionalParams != null) {
                Map<String, Schema.sObjectField> targetFields = Cash_Receipt__c.SObjectType.getDescribe().fields.getMap();
                for (String fieldApiName : options.additionalParams.keySet()) {
                    if (options.additionalParams.get(fieldApiName) != null) {
                        Schema.DisplayType valueType = targetFields.get(fieldApiName).getDescribe().getType();
                        if (valueType == Schema.DisplayType.BOOLEAN) {
                            cashReceipt.put(fieldApiName, (Boolean) options.additionalParams.get(fieldApiName));
                        }
                        else if (valueType == Schema.DisplayType.DATE) {
                            cashReceipt.put(fieldApiName, Date.valueOf((String) options.additionalParams.get(fieldApiName)));
                        }
                        else if (valueType == Schema.DisplayType.DATETIME) {
                            cashReceipt.put(fieldApiName, Datetime.valueOf((String) options.additionalParams.get(fieldApiName)));
                        }
                        else {
                            cashReceipt.put(fieldApiName, options.additionalParams.get(fieldApiName));
                        }
                    }
                }
            }

            populatePayeeDataFromCustomer(cashReceipt);

            if(options.paymentType != NULL){
                cashReceipt.Payment_Type__c = options.paymentType;
            }
            else {
                cashReceipt.Payment_Type__c = PAYMENT_TYPE_CHECK;
            }
           

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                cashReceipt.put('CurrencyIsoCode', options.currencyIsoCode);
                cashReceipt.Currency_Conversion_Rate__c = options.currencyConversionRate;

            }

            CashReceiptActions.isSkipAutoGLAVsFromAccount = true;            
            Database.SaveResult saveResult = SFDCSecurityUtils.insertCheckCRUDAndFLS(cashReceipt, new List<String>{
                'Purpose__c',
                'Amount__c',
                'Receipt_Date__c',
                'Account__c',
                'Ledger__c',
                'Bank_Account__c',
                'Description__c',
                'Cash_Flow_Category__c',
                'Payment_Type__c',
                'Memo__c',
                'Payment_Reference__c',
                'Accounting_Period__c',
                'Project__c',
                'Project_Task__c', 
                'GL_Account_Variable_1__c', 
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c', 
                'GL_Account_Variable_4__c'
            });

            CashReceiptActions.isSkipAutoGLAVsFromAccount = false;        
            if (saveResult.isSuccess()) {
                result = new ServiceResult(cashReceipt.Id, true);
            } else {
                List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                for (Database.Error dbError : saveResult.getErrors()) {
                    ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                    errors.add(err);
                }
                result = new ServiceResult(NULL, false, errors);
            }
        }
        catch (DmlException dmlEx) {
            result = new ServiceResult(NULL, dmlEx.getTypeName(), dmlEx.getDmlMessage(0).unescapeHtml4());
        }
        catch(Exception ex){
            result = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }   
            
        return result;
    }

    private static void populatePayeeDataFromCustomer(Cash_Receipt__c cashReceipt) {

        //get customer, single ID is passed in, only one record returned
        Account customer = DomainUtils.getAccountsById(new Set<Id>{cashReceipt.Account__c})[0];
        
        cashReceipt.Alternate_Payee_Name__c = customer.Alternate_Payee_Name__c;
        cashReceipt.Payee_Street__c = customer.BillingStreet;
        cashReceipt.Payee_City__c = customer.BillingCity;
        cashReceipt.Payee_State__c = customer.BillingState;
        cashReceipt.Payee_Postal_Code__c = customer.BillingPostalCode;
        cashReceipt.Payee_Country__c = customer.BillingCountry;

    }    


    @future
    private static void postFundingCreditMemoFuture(Id fundingCreditMemoId){   
        Billing.post(fundingCreditMemoId);
    }

    //=========================   APPLICATIONS   ===========================================
    private ServiceResult createBillingCreditMemo(Id billingId, Id creditMemoId, Decimal applyAmount, Date applyDate, Id acctPeriodId){
        ServiceResult result;
        try{
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Amount__c = applyAmount * -1;
            bcm.Billing_Credit_Memo__c = creditMemoId;
            bcm.Billing_Invoice__c = billingId;
            bcm.Accounting_Period__c = acctPeriodId;
            bcm.Applied_Date__c = applyDate;
    
            Database.SaveResult saveResult = SFDCSecurityUtils.insertCheckCRUDAndFLS(bcm, new List<String>{
                'Amount__c',
                'Billing_Credit_Memo__c',
                'Billing_Invoice__c'
            });

            if (saveResult.isSuccess()) {
                result = new ServiceResult(bcm.Id, true);
            } else {
                List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                for (Database.Error dbError : saveResult.getErrors()) {
                    ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                    errors.add(err);
                }
                result = new ServiceResult(NULL, false, errors);
            }
        }catch(Exception ex){
            result = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage().unescapeHtml4());
        }
       
        return result;
    }

    private ServiceResult createBillingCashReceipt(boolean createAsRefund){
        ServiceResult result;
        try{
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Applied_Date__c = options.refundDate;
            bcr.Billing__c = options.billingId;
            bcr.Cash_Receipt__c = options.cashReceiptId;  
            if(createAsRefund){
                bcr.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND ; 
                bcr.Applied_Amount__c = options.refundAmount ;
            }else {
                bcr.Applied_Amount__c = options.refundAmount * -1;
            }
    
            Database.SaveResult saveResult = SFDCSecurityUtils.insertCheckCRUDAndFLS(bcr, new List<String>{
                'Applied_Amount__c',
                'Billing__c',
                'Cash_Receipt__c'
            });

            if (saveResult.isSuccess()) {
                result = new ServiceResult(bcr.Id, true);
            } else {
                List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                for (Database.Error dbError : saveResult.getErrors()) {
                    ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                    errors.add(err);
                }
                result = new ServiceResult(NULL, false, errors);
            }
        }
        catch (DmlException dmlEx) {
            result = new ServiceResult(NULL, dmlEx.getTypeName(), dmlEx.getDmlMessage(0).unescapeHtml4());
        }
        catch(Exception ex){
            result = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
       
        return result;
    }

    //=========================   VALIDATIONS   ===========================================
    private Boolean validateInput() {
        if (billingModel == NULL) {
            ServiceResult.Error error = new ServiceResult.Error(NO_INPUT_DATA);
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        }else{
            serviceResult = new ServiceResult(NULL, true);
        }

        return serviceResult.isSuccess;
    }

    private Boolean validateAccountingPeriod(){

        if (acctPeriodForApply == null) {
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_APPLIED_DATE_INVALID);
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        }
        else{
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult.isSuccess;
    }

    private Boolean validateOptions(){

        if (options == NULL) {
            ServiceResult.Error error = new ServiceResult.Error(NO_INPUT_DATA);
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        } else{
            serviceResult = new ServiceResult(NULL, true);
        }

        return serviceResult.isSuccess;

    }

    private Boolean validateFundingCreditMemoOptions(){

        if(options.cashReceiptId == NULL){
            ServiceResult.Error error = new ServiceResult.Error(NO_INPUT_DATA);
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        } else if(options.sourceRecordBalance <= 0){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_NEGATIVE_BALANCE);
            serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
        } else if(options.refundAmount <= 0){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_LESS_THAN_ZERO);
            serviceResult = new ServiceResult(options.sourceRecordId, false, new ServiceResult.Error[]{error});
        } else if(options.refundAmount > options.sourceRecordBalance ){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_AMOUNT_GREATER_BALANCE);
            serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
        } else if(options.refundDate < options.sourceRecordDate){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_REFUND_DATE_INVALID);
            serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
        } else{
            serviceResult = new ServiceResult(NULL, true);
        }

        return serviceResult.isSuccess;

    }

    private Boolean validateRefundCashReceiptOptions(){
        if(options.billingId == NULL){
            ServiceResult.Error error = new ServiceResult.Error(NO_INPUT_DATA);
            serviceResult = new ServiceResult(NULL, false, new ServiceResult.Error[]{error});
        } else if(!options.isSourceCreditMemo){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_INVALID_TYPE);
            serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
        } else if(math.abs(options.refundAmount) > math.abs(options.sourceRecordBalance) ){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_AMOUNT_GREATER_CM_BALANCE);
            serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
        } else if(options.bankAccount == null){
            ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_REQUIRED_BANK_ACCOUNT);
            serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
        } else if(options.bankAccount != null){
            List<GL_Account__c> glAccounts = DomainUtils.getGlAccountsById(new Set<Id> {options.bankAccount});
            if (!glAccounts.isEmpty() && !glAccounts[0].Bank__c) {
                ServiceResult.Error error = new ServiceResult.Error(ERR_REFUND_BANK_ACCOUNT_MUST_ENABLED);
                serviceResult = new ServiceResult(options.cashReceiptId, false, new ServiceResult.Error[]{error});
            }
        } else{
            serviceResult = new ServiceResult(NULL, true);
        }

        return serviceResult.isSuccess;

    }

}