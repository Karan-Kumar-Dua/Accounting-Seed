public with sharing class CxTxnsUpdater {
    // is multicurrency enabled
    private static Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    private static final Integer REPORTING_DAYS_MAX = 60;
    private CxClient srvc;
    private CxAJRLogger logger;

    public CxTxnsUpdater(CxAJRLogger logger) {
        this.logger = logger;
        this.srvc = new CxClient();
    }
    public CxTxnsUpdater(CxClient srvc, CxAJRLogger logger) {
        this.srvc = srvc;
        this.logger = logger;
    }

    /**
     * fetches the activity status from cardknox and updates the payment activities
     * fetches the batchedd from cardknox 
     * create bank deposits for settled activities
     */
    public ProcessedBankDeposits updateActivities(List<Payment_Activity__c> scope, DateTime endDate){
        //to store all the activities with their payment processor
        Map<Id,List<Payment_Activity__c>> activitiesWithProcessors = new Map<Id,List<Payment_Activity__c>>(); 
        //cardknox batch ids with their batch reports
        Map<String,CardknoxService.BatchReport> batchIdsWithBatchReport = new Map<String,CardknoxService.BatchReport>(); 
        //cardknox batch ids with their existing bank deposits
        Map<String,Bank_Deposit__c> existingBankDeposits = new Map<String,Bank_Deposit__c>();
        //cardknox batch ids with their new bank deposits
        Map<String,Bank_Deposit__c> newBankDeposits = new Map<String,Bank_Deposit__c>();        
        //split bank deposit accross ledger
        Map<String,List<Payment_Activity__c>> compositeBatchLedgerWithPaymentActivities = new Map<String,List<Payment_Activity__c>>();
        //split cash receipt total amount as per ledger 
        Map<String,Decimal> compositeBatchLedgerWithCRAmountTotal = new Map<String,Decimal>();
        //variable to keep payment batch id with payment processor
        Map<String,String> batchIdsWithPaymentProcessors = new Map<String,String>();

        // an instance of inner class
        // successfulBDIds to keep all the succeeded bank deposits
        // failedBDIds to keep all failed bank deosits
        ProcessedBankDeposits processedBD = new ProcessedBankDeposits();
        List<Database.SaveResult> saveResults;

        /// apply filters to the activities
        List<Payment_Activity__c> activities = filterActivities(scope);

        //storing activities with their parent payment processors
        for(Payment_Activity__c activity : activities){
            Id processorId = activity.Payment_Method__r.Payment_Processor__c;
            if(activitiesWithProcessors.containsKey(processorId)){
                activitiesWithProcessors.get(processorId).add(activity);                
            }else{
                activitiesWithProcessors.put(processorId, new List<Payment_Activity__c>{activity});
            }
        }

        //to fetch the payment processors
        Map<Id,Payment_Processor__c> paymentProcessors = new Map<Id,Payment_Processor__c>(
                DomainUtils.getPaymentProcessorsById(activitiesWithProcessors.keySet()));

        for(Id processorId : activitiesWithProcessors.keySet()){
            List<Payment_Activity__c> mappedActivities = activitiesWithProcessors.get(processorId);
            try{
                // calculate the dates from between the first and last payment activities and create composite collection
                calculateDatesAndPrepareCompositeCollection(
                    mappedActivities,
                    paymentProcessors.get(processorId),
                    batchIdsWithBatchReport,
                    compositeBatchLedgerWithPaymentActivities,
                    endDate,
                    batchIdsWithPaymentProcessors
                ); 
            }catch(CardknoxService.CardknoxServiceException ex){
                logger.logError(processorId,ex.getMessage());
            }catch(Exception ex){
                logger.logError(processorId,ex.getMessage());
            }
        }
        //for loop to prepare a map to keep the batch ids with all cash receipts total amount
        for(String compositeKey : compositeBatchLedgerWithPaymentActivities.keySet()){
            Decimal total = 0;
            //inner loop to calculate total cash receipt amount per ledger
            for(Payment_Activity__c activity : compositeBatchLedgerWithPaymentActivities.get(compositeKey)){
                total+= activity.Cash_Receipt__r.Amount__c;
            }  
            compositeBatchLedgerWithCRAmountTotal.put(compositeKey,total);
        }

        //fecth existing bank deposits to update their amount and ledger amount
        for(Bank_Deposit__c bd : DomainUtils.getBankDepositsByBatchId(batchIdsWithBatchReport.keySet())){
            if(compositeBatchLedgerWithCRAmountTotal.containsKey(bd.Merchant_Batch_Id__c+':'+bd.Ledger__c)){
                bd.Amount__c = bd.Amount__c + compositeBatchLedgerWithCRAmountTotal.get(bd.Merchant_Batch_Id__c+':'+bd.Ledger__c);
                bd.Ledger_Amount__c = bd.Amount__c;
            }
            existingBankDeposits.put(bd.Merchant_Batch_Id__c+':'+bd.Ledger__c,bd);
        }

        //check if bank deposit exists
        if(existingBankDeposits.values().size() > 0 ){
            //update the existing bank deposits for amount
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c
            });
            saveResults = SFDCSecurityUtils.updateCheckCRUDAndFLS(
                            existingBankDeposits.values(), 
                            new List<String>{'Amount__c', 'Ledger_Amount__c'}, 
                            false
                        );
            TriggerObserver.purgeUnlockedFields(
                new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c
            });
            // store all failed and passed bank deposits
            processedBD = getProcessedBankDeposits(saveResults,processedBD,batchIdsWithPaymentProcessors,existingBankDeposits.values());
        }

        //creating new bank deposits 
        for(String compositeBatchLedger : compositeBatchLedgerWithPaymentActivities.keySet()){
            if(!existingBankDeposits.containsKey(compositeBatchLedger)){
                newBankDeposits.put(
                    compositeBatchLedger, 
                    createBankDeposits(
                        compositeBatchLedgerWithPaymentActivities.get(compositeBatchLedger)[0],
                        batchIdsWithBatchReport.get(compositeBatchLedger.split(':')[0]),
                        compositeBatchLedgerWithCRAmountTotal,
                        compositeBatchLedger
                    )
                );
            }
        }

        //insert the new bank deposits
        if(newBankDeposits.values().size() > 0){
            BankDepositActions.isPreventInsertDefaultFieldOverride = true;
            saveResults = SFDCSecurityUtils.insertProxy(newBankDeposits.values(),false);
            // store all failed and passed bank deposits
            processedBD = getProcessedBankDeposits(saveResults,processedBD,batchIdsWithPaymentProcessors,newBankDeposits.values());
            BankDepositActions.isPreventInsertDefaultFieldOverride = false;
        }

        // it will contain all the unique cash receipts and will further got the bank deposits link to them
        Map<Id,Cash_Receipt__c> receipts = new Map<Id,Cash_Receipt__c>();
        Map<Id,String> bankDepositWithBatchId = new Map<Id,String>();

        //update the cash receipts with batch ids 
        for(String compositeBatchLedger : compositeBatchLedgerWithPaymentActivities.keySet()){
            for(Payment_Activity__c activity : compositeBatchLedgerWithPaymentActivities.get(compositeBatchLedger)){
                //if existing has matching batch id then use that bank deposit id
                //else get the id from new bank deposits 
                Bank_Deposit__c bd = existingBankDeposits.get(compositeBatchLedger) != null ?
                                    existingBankDeposits.get(compositeBatchLedger) : newBankDeposits.get(compositeBatchLedger);
                // map to get rid of duplicate cash receipts in the collections
                receipts.put(
                    activity.Cash_Receipt__c,
                    new Cash_Receipt__c(
                        Id=activity.Cash_Receipt__c,
                        Bank_Deposit__c = bd.Id
                    )
                );
                bankDepositWithBatchId.put(bd.Id,bd.Merchant_Batch_Id__c);
            }
        }

        // update cash receipts 
        // unlock the bank deposit field to successfully update it in Cash Receipts
        TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});
        saveResults = SFDCSecurityUtils.updateProxy(receipts.values(), false);
        TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});
        
        String error;
        // iterate on the result to filter out succeeded and failed bank deposits
        for (Integer i = 0; i < receipts.values().size(); i++) {
            processedBD.processedPPIds.add(batchIdsWithPaymentProcessors.get(bankDepositWithBatchId.get(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c)));
            error = '';
            // only add when not already present in the list
            // don't add once failed bank deposits into the succeeded list
            // remove bank deposit from success list if it is a failure one
            if (saveResults.get(i).isSuccess() && 
                    !processedBD.failedBDIds.contains(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c) && 
                    !processedBD.successfulBDIds.contains(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c)) {
                processedBD.successfulBDIds.add(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c);
            }else if(!saveResults.get(i).isSuccess() && 
                    !processedBD.failedBDIds.contains(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c)){
                processedBD.failedBDIds.add(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c);
                processedBD.successfulBDIds.remove(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c);
                processedBD.failedBdProcessorIds.add(batchIdsWithPaymentProcessors.get(bankDepositWithBatchId.get(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c)));
                
                for(Database.Error err : saveResults.get(i).getErrors()) {
                    error = error + err.getMessage() + ', ';
                }
                logger.logError(batchIdsWithPaymentProcessors.get(bankDepositWithBatchId.get(receipts.get(saveResults.get(i).getId()).Bank_Deposit__c)),error.substringBeforeLast(', '));
            }
        }
        // return inner class instance to let the caller know about the updated bank deposits
        return processedBD;
    }

    /**
     * takes activities to calculate start/end date and prepare composite collection
     * payment processor to help in callout, batchIdsWithBatchReport to hold batch ids with report data
     * compositeCollection to prepare and store the composite collection
     * it first calculates the start and end date and then fetches the batch reports
     * further then it creates the composite collection
     *
     * @param activities A collection of activities to be processed.
     * @param pp The PaymentProcessor instance to be used for callouts.
     * @param batchIdsWithBatchReport A map of batch Ids and their corresponding batch report data.
     * @param compositeCollection A collection where the resultant composite data will be stored.
     * @param endDate The end date for the activity period.
     * @param batchIdsWithPaymentProcessors A map of batch Ids and their corresponding PaymentProcessor instances.
     */
    private void calculateDatesAndPrepareCompositeCollection(
            List<Payment_Activity__c> activities,
            Payment_Processor__c pp,
            Map<String,CardknoxService.BatchReport> batchIdsWithBatchReport,
            Map<String,List<Payment_Activity__c>> compositeCollection,
            Datetime endDate,
            Map<String,String> batchIdsWithPaymentProcessors
    ) {
 
        // find the oldest payment activity
        DateTime startDate = getEarliestPaymentDate(activities);
        // date range to report on
        DateRange range = new DateRange(startDate, endDate);
        // cardknox only allows 60 days at a time so we iterate over the range in 60 day chunks
        Iterator<DateRange> itr = range.iterator(REPORTING_DAYS_MAX);

        DateRange currentRange; // the 60 day chunk we are currently reporting on
        while(itr.hasNext()) {
            // get the next 60 day chunk
            currentRange = itr.next(); 
            // callout to cardknox to get the batch report
            CardknoxService.BatchReport report = srvc.getTransactionBatchReport(
                    currentRange.startDate(),
                    currentRange.endDate(),
                    pp);

            if(!String.isBlank(report?.xError)){
                logger.logError(activities[0].Payment_Method__r.Payment_Processor__c,report.xError);
                continue;
            }
            if(report == null || report.xReportData.isEmpty()){
                // nothing found
                continue;
            }

            // a CardknoxService.BatchReport contains a list of CardknoxService.BatchReportData
            // to create the bank deposit we must make sure that each BatchReportData is processed
            for(CardknoxService.BatchReportData reportDetail : report.xReportData){
                // empty dates means batch has not settled
                if(String.isBlank(reportDetail.xBatchDate) && String.isBlank(reportDetail.xBatchTime)){
                    continue;
                }
                // deserialize report data
                CardknoxService.BatchReport reportData = (CardknoxService.BatchReport)JSON.deserialize(JSON.serialize(report), CardknoxService.BatchReport.class);
                reportData.xReportData = new List<CardknoxService.BatchReportData>{reportDetail};
                // keep every batch id with their reports
                batchIdsWithBatchReport.put(reportDetail.xBatch,reportData);
                // make the collection with activity and report data
                prepareCompositeCollection(activities,compositeCollection,reportDetail,batchIdsWithPaymentProcessors);
            }
        }
    }

    /**
     * takes activities to help in composite keys
     * compositeCollection to add or update new composite collections
     * reportDetail for incuding batch report details
     * it creates and update the composite collection with batch ids and ledger of the cash receipts
    */
    private void prepareCompositeCollection(
            List<Payment_Activity__c> activities, 
            Map<String,List<Payment_Activity__c>> compositeCollection,
            CardknoxService.BatchReportData reportDetail,
            Map<String,String> batchIdsWithPaymentProcessors
    ){
        // prepare composite key with the use of batch Id and Ledger Id
        for(Payment_Activity__c activity : activities){
            batchIdsWithPaymentProcessors.put(reportDetail.xBatch,activity.Payment_Method__r.Payment_Processor__c);
            if (reportDetail.xBatch != activity.Merchant_Batch_Id__c) {
                // activity does not belong to this cx batch
                continue;
            }
            // continue if activity is already exists
            if(compositeCollection.containsKey(reportDetail.xBatch+':'+activity.Cash_Receipt__r.Ledger__c) && 
                compositeCollection.get(reportDetail.xBatch+':'+activity.Cash_Receipt__r.Ledger__c)?.contains(activity)){
                continue;
            }
            if(compositeCollection.containsKey(reportDetail.xBatch+':'+activity.Cash_Receipt__r.Ledger__c)){
                compositeCollection.get(reportDetail.xBatch+':'+activity.Cash_Receipt__r.Ledger__c).add(activity);
            }else{
                compositeCollection.put(reportDetail.xBatch+':'+activity.Cash_Receipt__r.Ledger__c, 
                                                        new List<Payment_Activity__c> {activity});
            }
        } 
    }
     //creates bank deposits
     private Bank_Deposit__c createBankDeposits(Payment_Activity__c activity,
                                                    CardknoxService.BatchReport report,
                                                    Map<String,Decimal> compositeBatchLedgerWithCRAmountTotal,
                                                    String compositeBatchLedger){
        String[] batchLedger = compositeBatchLedger.split(':');
        Bank_Deposit__c deposit = new Bank_Deposit__c();
        deposit.Deposit_Date__c = report.xReportData[0].xBatchDateTimeUTC().dateGMT();
        deposit.Merchant_Batch_Id__c = report.xReportData[0].xBatch;
        deposit.Bank_Account__c = activity.Payment_Method__r.Payment_Processor__r.Merchant_GL_Account__c;
        deposit.Deposit_Reference__c = report.xRefNum;
        deposit.Ledger__c = batchLedger[1];
        deposit.Amount__c = compositeBatchLedgerWithCRAmountTotal.get(compositeBatchLedger).setScale(2, System.RoundingMode.HALF_UP);
        deposit.Ledger_Amount__c = deposit.Amount__c;
        if (isMultiCurrencyEnabled) {
            deposit.put('CurrencyIsoCode', LedgerHandler.getLedgerCurrency(Id.ValueOf(batchLedger[1])));
        }
        return deposit;
    }
    // inner class to keep records of the succeeded and failed bank deposits
    public class ProcessedBankDeposits{
        // will keep track of all successfully created and updated bank deposits
        public Set<Id> successfulBDIds;
        // will keep track of all failed bank deposits
        public Set<Id> failedBDIds;
        //will keep all the processed payment processor Ids
        public Set<Id> processedPPIds;
        //will keep all the processed payment processor Ids
        public Set<Id> failedBdProcessorIds;
        // will hold failed merchant batch Id of PA
        public Set<String> failedMerchantBatchId;
        
        public ProcessedBankDeposits(){
            this.successfulBDIds = new Set<Id>();
            this.failedBDIds = new Set<Id>();
            this.processedPPIds = new Set<Id>();
            this.failedBdProcessorIds = new Set<Id>();
            this.failedMerchantBatchId = new Set<String>();
        }

        public void add(ProcessedBankDeposits additions) {
            this.successfulBDIds.addAll(additions.successfulBDIds);
            this.failedBDIds.addAll(additions.failedBDIds);
            this.processedPPIds.addAll(additions.processedPPIds);
            this.failedBdProcessorIds.addAll(additions.failedBdProcessorIds);
            this.failedMerchantBatchId.addAll(additions.failedMerchantBatchId);
            this.successfulBDIds.removeAll(this.failedBDIds);
        }
    }

    // iterate on the save results to filter out succeeded and failed bank deposits
    private ProcessedBankDeposits getProcessedBankDeposits(
            List<Database.SaveResult> results,
            ProcessedBankDeposits processedBD,
            Map<String,String> batchIdsWithPaymentProcessors,
            List<Bank_Deposit__c> bankDeposits){
        String error;
        for (Integer i = 0; i < results.size(); i++) {
            processedBD.processedPPIds.add(batchIdsWithPaymentProcessors.get(bankDeposits[i].Merchant_Batch_Id__c));
            if (results.get(i).isSuccess()) {
                processedBD.successfulBDIds.add(results.get(i).getId());
            }else {
                processedBD.failedBDIds.add(results.get(i).getId());
                processedBD.failedBdProcessorIds.add(batchIdsWithPaymentProcessors.get(bankDeposits[i].Merchant_Batch_Id__c));
                error = '';
                for(Database.Error err : results.get(i).getErrors()) {
                    error = error + err.getMessage() + ', ';
                }
                logger.logError(batchIdsWithPaymentProcessors.get(bankDeposits[i].Merchant_Batch_Id__c),error.substringBeforeLast(', '));
            }
        }
        // return inner class instance to let the caller know about the updated bank deposits
        return processedBD;
    }

    /**
     * filters out the activities which are not in ledger currency
     */
    private List<Payment_Activity__c> filterActivities(List<Payment_Activity__c> unfiltered) {
        if (!isMultiCurrencyEnabled) {
            return unfiltered;
        }
        
        List<Payment_Activity__c> filtered = new List<Payment_Activity__c>();
        for (Payment_Activity__c activity : unfiltered) {
            if (LedgerHandler.isLedgerCurrency((String)activity.Cash_Receipt__r.get('CurrencyIsoCode'), activity.Cash_Receipt__r.Ledger__c)) {
                // cash receipt is in ledger currency
                filtered.add(activity);
            }
        }
        return filtered;
    }

    /**
     * returns the earliest payment date from the list of payment activities
     */
    @TestVisible
    private static DateTime getEarliestPaymentDate(List<Payment_Activity__c> activities) {
        DateTime earliest;
        for (Payment_Activity__c activity : activities) {
            DateTime dt;
            if (activity.Payment_Date__c != null) {
                // the best option is the payment date from the payment activity
                dt = activity.Payment_Date__c;
            } else if (activity.Cash_Receipt__r.Receipt_Date__c != null) {
                // next best option is the receipt date from the cash receipt
                // becuase CRs are Date only (no Time) we should set the time to 00:00:00
                dt = DateTime.newInstanceGmt(activity.Cash_Receipt__r.Receipt_Date__c, Time.newInstance(0,0,0,0));
            } else {
                // last resort use created date from payment activty -1 day to be safe
                dt = DateTime.newInstanceGmt(activity.CreatedDate.date().addDays(-1), Time.newInstance(0,0,0,0));
            }

            // compare this payment activity's date to the earliest found so far
            if (earliest == null || dt < earliest) {
                earliest = dt;
            }
        }
        return earliest;
    }

    @TestVisible
    private with sharing class DateRange {
        private DateTime startDate;
        private DateTime endDate;
        public DateRange(DateTime startDate, DateTime endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
        public DateTime startDate() {
            return this.startDate;
        }
        public DateTime endDate() {
            return this.endDate;
        }
        public Iterator<DateRange> iterator(Integer stepDays) {
            return (new DateRangeIterable(this, stepDays)).iterator();
        }
    }

    @TestVisible
    private with sharing class DateRangeIterator implements Iterator<DateRange>{ 
        private Integer step;
        DateRange range;
        DateRange window;

        public DateRangeIterator(DateRange range, Integer stepDays) {
            this.range = range;
            this.step = stepDays;
            this.window = new DateRange(range.startDate(), range.startDate());
        }

        public Boolean hasNext() { 
            return window.endDate() < range.endDate();
        }

        public DateRange next() {
            if (hasNext()) {
                shiftWindow();
                return window;
            }
            return null;
        } 

        private void shiftWindow() {
            DateTime nextStart = window.endDate(); // move start date to end of previous window
            DateTime nextEnd = window.endDate().addDays(step); // step end date forward

            // shift end date back if it is past the end of the range
            if (nextEnd > range.endDate()) {
                nextEnd = range.endDate();
            }

            // create the next window
            this.window = new DateRange(nextStart, nextEnd);
        }
    }

    @TestVisible
    private with sharing class DateRangeIterable implements Iterable<DateRange> {
        private Integer step;
        private DateRange range;
        public DateRangeIterable(DateRange range, Integer stepDays) {
            this.range = range;
            this.step = stepDays;
        }
        public Iterator<DateRange> iterator() {
           return new DateRangeIterator(range, step);
        }
    } 
}