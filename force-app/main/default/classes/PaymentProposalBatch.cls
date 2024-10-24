public with sharing class PaymentProposalBatch implements Database.Batchable<SObject>, Database.Stateful{
    
    private Map<Id, Cash_Disbursement_Batch__c> payPropIdToCashDisbBatch = new  Map<Id, Cash_Disbursement_Batch__c>();
    private Set<Id> paymentProposalIds = new Set<Id>();

    private String query = 'SELECT Id, Error__c, Payment_Proposal__c FROM AcctSeed__Payment_Proposal_Line__c '
                            + 'WHERE Payment_Proposal__r.Status__c = \'Approved\' '
                            + 'AND Status__c != \'Paid\' '
                            + 'AND (Payment_Proposal__r.Aggregate_by_Payee__c = false OR (Payment_Proposal__r.Aggregate_by_Payee__c = true AND Payable__c = null )) ';

    private static Final String ERR_PPL_AMOUNT_FIELD = Label.ERR_PPL_AMOUNT_FIELD;
    private static Final String ERR_PPL_POST_STATUS = Label.ERR_PPL_POST_STATUS; 
    private static Final String ERR_ACCOUNTING_PERIOD_CLOSED = Label.ERR_ACCOUNTING_PERIOD_CLOSED;
    private static Final String ERR_LEDGER_MISMATCH = Label.ERR_DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR;
    private static Final String ERR_PPL_AMOUNT_TO_PAY_ZERO = Label.ERR_PPL_AMOUNT_TO_PAY_ZERO;
    private static Final String RECENT_PERIOD_MEMO_ERROR = Label.ERR_RECENT_PERIOD_MEMO;
    private static Final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    private static Final String CASH_DISBURSEMENT_BATCH_NAME = Label.CASH_DISBURSEMENT_BATCH_NAME;
    private static Final String STATUS_APPROVED = 'Approved';
    private static Final String STATUS_POSTED = 'Posted';
    private static Final String STATUS_PAID = 'Paid';
    private static Final String STATUS_PENDING = 'Pending';
    private static Final String STATUS_ERROR = 'Error';
    private static Final String SOURCE = 'Manual';

    private String queryFields = 'Id , Name , Payment_Proposal__c , Amount__c , Vendor__r.AS_Pay_Type__c, Payable__c, ' 
    + 'Vendor__c , Current_Balance__c ,Payment_Proposal__r.Bank_GL_Account__c, Due_Date__c , Early_Pay_Date__c , Discount_Amount__c, '
    + 'Issue_Date__c , Parent__c, Payment_Proposal__r.Ledger__c, Payable__r.Ledger__c, Payable__r.Name, Payable__r.Discount_Amount__c, '
    + 'Payable__r.Accounting_Period__c, Payment_Proposal__r.Status__c, Payment_Proposal__r.Name, Payment_Proposal__r.Account__c, '
    + 'Payment_Proposal__r.Type__c, Payment_Proposal__r.Aggregate_by_Payee__c, Is_Credit__c, Posting_Status__c, Payment_Proposal__r.Payment_Date__c ';

    private Map<Id, Payment_Proposal_Line__c> allPPLs;
    private Map<Id, Payment_Proposal_Line__c> errRecords;
    private Map<Id, Payment_Proposal_Line__c> successRecords;
    private Map<Id, Cash_Disbursement__c> pplIdToCashDisb;
    private Map<Id, Cash_Disbursement__c> childPPLIdToCashDisb;
    private Map<Id, AP_Disbursement__c> pplIdToAPD;
    private List<AP_Credit_Memo__c> apcmsToInsert;


    //Constructor to accomodate single PP record
    public PaymentProposalBatch(Payment_Proposal__c paymentProposal) {
        this.query += 'AND Payment_Proposal__c = \'' + paymentProposal.Id + '\' ';
    }

    //Constructor to accomodate multiple PP record
    public PaymentProposalBatch() {
        //all approved payment proposal only
        this.query += 'ORDER BY Payment_Proposal__r.Name';    
    }

    //Query Locator is getting all PPLs where Aggregate By Payee = FALSE AND Parent PPLs where Aggregate By Payee = TRUE
    public Database.QueryLocator start(Database.BatchableContext batchableContext) {
        this.queryFields += (IS_MULTI_CURRENCY_ENABLED)?',Payment_Proposal__r.CurrencyISOCode':'';
        
        publishPayPropPublishStartPlatformEvent();
        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext batchableContext, List<Payment_Proposal_Line__c> payPropLines) {
        //init variables for this execution
        allPPLs = new Map<Id, Payment_Proposal_Line__c>();
        errRecords = new Map<Id, Payment_Proposal_Line__c>();
        successRecords = new Map<Id, Payment_Proposal_Line__c>();
        pplIdToCashDisb = new Map<Id, Cash_Disbursement__c>();
        childPPLIdToCashDisb = new Map<Id, Cash_Disbursement__c>();
        pplIdToAPD = new Map<Id, AP_Disbursement__c>();
        apcmsToInsert = new List<AP_Credit_Memo__c>();

        this.query = 'SELECT ' + queryFields + ' , (SELECT ' + queryFields + ' FROM Payment_Proposal_Lines_Child__r ORDER BY Issue_Date__c ASC) '
        + 'FROM AcctSeed__Payment_Proposal_Line__c '
        + 'WHERE Id in :payPropLines'; 

        List<Payment_Proposal_Line__c> payPropLinesWithChildren = Database.query(query);

         //Create Cash Disbursements Batch
         createCDBatch(payPropLinesWithChildren);

        for(Payment_Proposal_Line__c ppl : (List<Payment_Proposal_Line__c>) payPropLinesWithChildren) {
            allPPLs.put(ppl.Id, ppl);

            //Aggregate by Payee = false, each PPL has a CD and APD
            if(!ppl.Payment_Proposal__r.Aggregate_by_Payee__c) {
                if(validatePPL(ppl)){
                    Cash_Disbursement__c newCD = createCD(ppl);
                    pplIdToCashDisb.put(ppl.id, newCD);
                    pplIdToAPD.put(ppl.id, createAPD(ppl, newCD));
                }
            } else {
                boolean errorWithChildLines = false;
                if(ppl.Payment_Proposal_Lines_Child__r?.size() > 0 ){
                    List<Payment_Proposal_Line__c> creditPPLs = new List<Payment_Proposal_Line__c>();
                    Map<Id, Payment_Proposal_Line__c> invoicePPLs = new Map<Id, Payment_Proposal_Line__c>();
                  
                    //separate credits from invoices
                    for(Payment_Proposal_Line__c childPPL : ppl.Payment_Proposal_Lines_Child__r){
                        //add child lines to flattened collection of all lines
                        allPPLs.put(childPPL.Id, childPPL);
                        if(validatePPL(childPPL)){
                            if(childPPL.Is_Credit__c){ 
                                creditPPLs.add(childPPL);
                            }else{
                                invoicePPLs.put(childPPL.Id, childPPL);
                            }
                        }else{
                            //set error flag and break from loop if there are any errors we are skipping the parent
                            errorWithChildLines = true;
                            //add error for parent line
                            errRecords.put(ppl.Id, new Payment_Proposal_Line__c( Id = ppl.Id, Status__c = STATUS_ERROR));
                            break;
                        }
                    }

                    //only create APCM, CD, APD if all child lines were valid
                    if(!errorWithChildLines){
                        createAppliedCreditMemos(creditPPLs, invoicePPLs);
                       
                        //If all invoice lines were paid with APCM then the collection will be empty, no need fo CD or APD
                        if(invoicePPLs.values() != null && invoicePPLs.values().size() > 0){
                            //Create CD for Parent Line
                            Cash_Disbursement__c newCD = createCD(ppl);
                            pplIdToCashDisb.put(ppl.id, newCD);
                            //Create APDs for
                            for(Payment_Proposal_Line__c childPPL : invoicePPLs.values()){
                                pplIdToAPD.put(childPPL.Id, createAPD(childPPL, newCD));
                                childPPLIdToCashDisb.put(childPPL.id, newCD);
                            }
                        }
                    } 
                }
            }
            paymentProposalIds.add(ppl.Payment_Proposal__c);
        }

        //update discount amounts, has to be done prior to paying
        updatePayablesDiscountAmt(allPPLs);

        //Insert APCMs
        if(!apcmsToInsert.isEmpty()) {
            insertAPCMs(apcmsToInsert);
            //remove errors from further processessing
            removeErrorRecords();
        }
        
        //Insert CDs
        if(!pplIdToCashDisb.values().isEmpty()) {
            insertCDs(pplIdToCashDisb.values());
            //remove errors from further processessing
            removeErrorRecords();
        }

        //Insert APDs 
        if(pplIdToAPD.values().size() > 0){
            pplIdToCashDisb.putAll(childPPLIdToCashDisb);
            insertAPDs(pplIdToAPD.values(), pplIdToCashDisb);
        }

        updatePPLsStatusAndError();     
    }

    public void finish(Database.BatchableContext batchableContext) {
        PaymentProposalStatusBatch batch = new PaymentProposalStatusBatch(paymentProposalIds);
        Database.executeBatch(batch, 200); 

    }

    private void createAppliedCreditMemos(List<Payment_Proposal_Line__c> creditPPLs, Map<Id, Payment_Proposal_Line__c> invoicePPLs){
               //Create AP Credit Memos if CMs exist
               for(Payment_Proposal_Line__c creditPPL : creditPPLs){
                Decimal creditAmt = Math.abs(creditPPL.Amount__c);
                List<Id> invoicePPLsToRemove = new List<Id>();
                //loop over child payable PPLs
                Decimal appliedAmount = 0;
                for(Payment_Proposal_Line__c invoicePPL : invoicePPLs.values()){                  
                    if(creditAmt > 0 && invoicePPL.Amount__c <= creditAmt){
                        appliedAmount = invoicePPL.Amount__c;
                        //PPL is fully alocated no further processing needed
                        invoicePPLsToRemove.add(invoicePPL.Id);
                    }else if(creditAmt > 0 && invoicePPL.Amount__c > creditAmt){
                        appliedAmount = creditAmt;
                        //PPL is partially alocated, recduce PPL amount by amount allocated
                        invoicePPLs.get(invoicePPL.Id).Amount__c -= Math.abs(creditAmt);
                    }else if(creditAmt <= 0){
                        break;
                    }
                    //reduce credit amount by total applied
                    creditAmt -= appliedAmount;
                    apcmsToInsert.add(createAPCM(invoicePPL.Payable__c, creditPPL.Payable__c, invoicePPL, appliedAmount));

                    //Set Credit Memo PPL to Paid 
                    addSuccessPPL(creditPPL.Id);
                }
                invoicePPLs.keySet().removeAll(invoicePPLsToRemove);
            }
    }

    //CREATE METHODS******************************************************************
    private AP_Credit_Memo__c createAPCM(Id payableId, Id payableCreditMemoId, Payment_Proposal_Line__c ppl, Decimal creditAmt) {
        Accounting_Period__c paymentDateAccountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(ppl.Payment_Proposal__r.Payment_Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Account_Payable__c.SObjectType);
        AP_Credit_Memo__c apCreditMemoRecord = new AP_Credit_Memo__c(
            Account_Payable_Credit_Memo__c = payableCreditMemoId,
            Account_Payable_Invoice__c = payableId,
            Amount__c = -1 * creditAmt,
            Applied_Date__c = ppl.Payment_Proposal__r.Payment_Date__c,
            Payment_Proposal_Line__c = ppl.id,
            Accounting_Period__c = paymentDateAccountingPeriod.Id
        );

        if(IS_MULTI_CURRENCY_ENABLED){
            apCreditMemoRecord.put('CurrencyIsoCode', ppl.Payment_Proposal__r.get('CurrencyIsoCode'));
        }

        return apCreditMemoRecord;
    }

    private void createCDBatch(List<Payment_Proposal_Line__c> paymentProposalLines) {
        for(Payment_Proposal_Line__c ppl : paymentProposalLines) {

            if(!payPropIdToCashDisbBatch.containsKey(ppl.Payment_Proposal__c)) {
                //insert cash disbursement batch
                Cash_Disbursement_Batch__c cdb = new Cash_Disbursement_Batch__c(
                    Name = CASH_DISBURSEMENT_BATCH_NAME + ' ' + ppl.Payment_Proposal__r.Name
                );
                if(IS_MULTI_CURRENCY_ENABLED){
                    cdb.put('CurrencyIsoCode', ppl.Payment_Proposal__r.get('CurrencyIsoCode'));
                }
                //Stateful variable to store payment proposal with cash disbursement batch
                payPropIdToCashDisbBatch.put(ppl.Payment_Proposal__r.Id, cdb);
            }
        }

        SFDCSecurityUtils.insertCheckCRUDAndFLS(payPropIdToCashDisbBatch.values(), new List<String>{'Name'}, false);
        return; 
    }

    private Cash_Disbursement__c createCD(Payment_Proposal_Line__c ppl) {
        Cash_Disbursement__c cashDisbursementRec = new Cash_Disbursement__c(
                            //Amount__c = ppl.Amount__c != null ? ppl.Amount__c : ppl.Total__c,
                            Amount__c = ppl.Amount__c,
                            Ledger__c = ppl.Payment_Proposal__r.Ledger__c,
                            Type__c   = ppl.Payment_Proposal__r.Type__c,
                            Source__c = SOURCE,
                            Bank_Account__c = ppl.Payment_Proposal__r.Bank_GL_Account__c,
                            Vendor__c = ppl.Vendor__c,
                            Cash_Disbursement_Batch__c = payPropIdToCashDisbBatch.get(ppl.Payment_Proposal__c).Id,
                            Payment_Proposal__c = ppl.Payment_Proposal__c,
                            Payment_Proposal_Line__c = ppl.Id,
                            Disbursement_Date__c = ppl.Payment_Proposal__r.Payment_Date__c
                        );
        Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
        if(settings.CD_Set_to_Approved_for_Payment_Proposals__c == true){
            cashDisbursementRec.Status__c = STATUS_APPROVED;
        }

        if(IS_MULTI_CURRENCY_ENABLED){
            cashDisbursementRec.put('CurrencyIsoCode', ppl.Payment_Proposal__r.get('CurrencyIsoCode'));
        }

        return cashDisbursementRec;
    }

    private AP_Disbursement__c createAPD(Payment_Proposal_Line__c ppl, Cash_Disbursement__c cashDisb) { 
        AP_Disbursement__c apDisbursementRecord = new AP_Disbursement__c(
            Account_Payable__c = ppl.Payable__c,
            Cash_Disbursement__c = cashDisb.Id,
            Paid_Amount__c = ppl.Amount__c,
            Payment_Proposal_Line__c = ppl.Id,
            Applied_Date__c = ppl.Payment_Proposal__r.Payment_Date__c,
            Status__c = STATUS_APPROVED
        );

        if(IS_MULTI_CURRENCY_ENABLED){
            apDisbursementRecord.put('CurrencyIsoCode', ppl.Payment_Proposal__r.get('CurrencyIsoCode'));
        }

        return apDisbursementRecord;
    }

    //INSERT METHODS******************************************************************
    private void insertAPCMs(List<AP_Credit_Memo__c> APCMsToInsert){
        List<Database.SaveResult> saveResult = SFDCSecurityUtils.insertCheckCRUDAndFLS(APCMsToInsert, new List<String>{'Amount__c','Account_Payable_Credit_Memo__c',
            'Applied_Date__c','Account_Payable_Invoice__c','Accounting_Period__c'}, false);
           
        //loop over results and get error records if they exist
        for(Integer i=0 ; i < saveResult.size() ; i++){
            if(saveResult[i].isSuccess()){
                addSuccessPPL(APCMsToInsert[i].Payment_Proposal_Line__c);
            }else{
                string dmlErrorString = '';
                for(database.error err : saveResult[i].getErrors()){
                    dmlErrorString += SObjectType.AP_Credit_Memo__c.getLabel() + ': ' + err.message + '\r\n';
                }
                addErrorPPL(APCMsToInsert[i].Payment_Proposal_Line__c, dmlErrorString);
            } 
        }
    }

    private void insertCDs(List<Cash_Disbursement__c> cashDisbursementToInsert) {
        List<Database.SaveResult> saveResult = SFDCSecurityUtils.insertCheckCRUDAndFLS(cashDisbursementToInsert, new List<String>{'Status__c','Cash_Disbursement_Batch__c','Source__c'
            ,'Bank_Account__c','Amount__c','Ledger__c','Type__c', 'AS_Pay_Type__c','Accounting_Period__c','Vendor__c', 'Payment_Proposal__c', 'Payment_Proposal_Line__c'}, false);
     
        //loop over results and get error records if they exist
        for(Integer i=0 ; i < saveResult.size() ; i++){
            if(saveResult[i].isSuccess()){
                addSuccessPPL(cashDisbursementToInsert[i].Payment_Proposal_Line__c);
            }else{
                string dmlErrorString = '';
                for(database.error err : saveResult[i].getErrors()){
                    dmlErrorString += SObjectType.Cash_Disbursement__c.getLabel() + ': ' + err.message + '\r\n';
                }
                addErrorPPL(cashDisbursementToInsert[i].Payment_Proposal_Line__c, dmlErrorString);
            } 
        }
    }

    private void insertAPDs(List<AP_Disbursement__c> apDisbursementToInsert, Map<Id, Cash_Disbursement__c> pplIdToCashDisb){
        if(!apDisbursementToInsert.isEmpty()) {   
            for(AP_Disbursement__c apd : apDisbursementToInsert){
                apd.Cash_Disbursement__c = pplIdToCashDisb.get(apd.Payment_Proposal_Line__c).Id;
            }
            List<Database.SaveResult> saveResult = SFDCSecurityUtils.insertCheckCRUDAndFLS(apDisbursementToInsert, new List<String>{'Account_Payable__c','Cash_Disbursement__c', 'Paid_Amount__c','Applied_Date__c','Status__c', 'Payment_Proposal_Line__c' }, false);
            //loop over results and get error records if they exist
            for(Integer i=0 ; i < saveResult.size() ; i++){
                if(saveResult[i].isSuccess()){
                    addSuccessPPL(apDisbursementToInsert[i].Payment_Proposal_Line__c);
                }else{
                    string dmlErrorString = '';
                    for(database.error err : saveResult[i].getErrors()){
                        dmlErrorString += SObjectType.AP_Disbursement__c.getLabel() + ': ' + err.message + '\r\n';
                    }
                    addErrorPPL(apDisbursementToInsert[i].Payment_Proposal_Line__c, dmlErrorString);
                } 
            }
        }
    }

    //UPDATE METHODS******************************************************************
    private void updatePayablesDiscountAmt(Map<Id, Payment_Proposal_Line__c> ppls){
        List<Account_Payable__c> payablesToUpdate = new List<Account_Payable__c>();
        for(Payment_Proposal_Line__c ppl : ppls.values()){
            if(ppl.Payable__c != NULL && (ppl.Discount_Amount__c != null && ppl.Discount_Amount__c > 0)){
                payablesToUpdate.add(new Account_Payable__c(id = ppl.Payable__c, Discount_Amount__c = ppl.Discount_Amount__c));
            }    
        }
        List<Database.SaveResult> saveResult = SFDCSecurityUtils.updateCheckCRUDAndFLS(payablesToUpdate, new List<String>{'Discount_Amount__c'}, false);
    }

    private void updatePPLsStatusAndError(){
        Map<Id, Payment_Proposal_Line__c> pplsToUpdate = new Map<Id, Payment_Proposal_Line__c>();
        if(!successRecords.isEmpty() && successRecords.values().size() > 0) {
            pplsToUpdate.putAll(successRecords);
        }   
        if(!errRecords.isEmpty() && errRecords.values().size() > 0) {
            pplsToUpdate.putAll(errRecords);
        } 

        if(!pplsToUpdate.isEmpty()){
            List<Database.SaveResult> saveResult = SFDCSecurityUtils.updateCheckCRUDAndFLS(pplsToUpdate.values(), new List<String>{'Error__c', 'Status__c'}, false);
        }
    }

    //UTILITY METHODS****************************************************************
    private static void publishPayPropPublishStartPlatformEvent(){
        EventPubSub.publish(
            EventPubSub.createEvent(
                EventPubSub.PublishDelay.IMMEDIATE,
                EventRegistry.RegisteredEvent.PAYMENT_PROPOSAL_PUBLISH_START,
                FinancialSuiteUtils.getUUID(),
                NULL
            )
        );
    }

    private void addSuccessPPL(Id id){
        Payment_Proposal_Line__c successPPL = successPPL(id);
        successRecords.put(successPPL.id, successPPL);
    }

    private void addErrorPPL(Id id, String error){
        Payment_Proposal_Line__c errPPL = errorPPL(id, error);
        errRecords.put(errPPL.id, errPPL);
    }

    //remove PPLs from collections from future processessing if an error exists
    private void removeErrorRecords(){
        for(Payment_Proposal_Line__c ppl : errRecords.values()){
            pplIdToAPD.remove(ppl.Id);
            pplIdToCashDisb.remove(allPPLs.get(ppl.Id).Parent__c);
        }
    }

    private boolean validatePPL(Payment_Proposal_Line__c ppl){
        boolean isValid = false;
        Accounting_Period__c paymentDateAccountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(ppl.Payment_Proposal__r.Payment_Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Account_Payable__c.SObjectType);
        
        Accounting_Period__c mostRecentPeriod;

        if(paymentDateAccountingPeriod != null){
            mostRecentPeriod = AccountingPeriodHandler.getInstance().getMostRecentAccountingPeriodFromCollection(
                new Set<Id>{
                    paymentDateAccountingPeriod.Id,
                    ppl.Payable__r.Accounting_Period__c
                }
            );
        }

        if((ppl.Is_Credit__c && ppl.Amount__c < ppl.Current_Balance__c)|| (!ppl.Is_Credit__c && ppl.Amount__c > ppl.Current_Balance__c)){
            errRecords.put(ppl.id, errorPPL(ppl.Id, ERR_PPL_AMOUNT_FIELD));
        }else if(ppl.Amount__c == 0){
            errRecords.put(ppl.id, errorPPL(ppl.Id, ERR_PPL_AMOUNT_TO_PAY_ZERO));
        }else if(ppl.Posting_Status__c != STATUS_POSTED){
            errRecords.put(ppl.id, errorPPL(ppl.Id, ERR_PPL_POST_STATUS));
        }else if(paymentDateAccountingPeriod == null){
            errRecords.put(ppl.id, errorPPL(ppl.Id, ERR_ACCOUNTING_PERIOD_CLOSED));
        }else if(ppl.Payable__c != null && ppl.Payment_Proposal__r.Ledger__c != ppl.Payable__r.Ledger__c){
            errRecords.put(ppl.id, errorPPL(ppl.Id, String.format(ERR_LEDGER_MISMATCH, new List<String>{ppl.Payment_Proposal__r.Name, ppl.Payable__r.Name})));
        }else if(ppl.Payable__c != null && paymentDateAccountingPeriod != mostRecentPeriod ){
            errRecords.put(ppl.id, errorPPL(ppl.Id,  String.format(
                                                        RECENT_PERIOD_MEMO_ERROR,
                                                        new List<String>{AP_Disbursement__c.SObjectType.getDescribe().getLabel(), mostRecentPeriod.Name})) 
            );
        }else {
            isValid = true;
        }

        return isValid;
    }

    private Payment_Proposal_Line__c errorPPL(Id id, String error){
        return new Payment_Proposal_Line__c(Id = Id, 
            Status__c = STATUS_ERROR, 
            Error__c = SObjectType.Payment_Proposal_Line__c.getLabel() + ': ' + error);
    }

    private Payment_Proposal_Line__c successPPL(Id id){
        return new Payment_Proposal_Line__c(Id = id,
            Error__c = null,
            Status__c = STATUS_PAID);
    }

    
}