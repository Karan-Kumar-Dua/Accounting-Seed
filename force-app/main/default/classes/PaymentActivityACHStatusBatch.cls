public with sharing class PaymentActivityACHStatusBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String STATUS_ERROR = 'Error';
    private ProcessingReport pReport;
    private PaymentGateway gtwy;
    private Set<Id> voids;

    public PaymentActivityACHStatusBatch() {
        pReport = new ProcessingReport();
        gtwy = new PaymentGateway();
        voids = new Set<Id>();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query =
            'SELECT Id, Name, ' +
                    PACKAGE_QUALIFIER + 'Cash_Receipt__c, ' +
                    PACKAGE_QUALIFIER + 'Cash_Receipt__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Cash_Receipt__r.' + PACKAGE_QUALIFIER + 'Payment_Reference__c, ' +
                    PACKAGE_QUALIFIER + 'Status__c, ' +
                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Error_Message__c, ' +
                    PACKAGE_QUALIFIER + 'Error_Type__c, ' +
                    PACKAGE_QUALIFIER + 'Payment_Method__c, ' +
                    PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'External_Id__c, ' +
                    PACKAGE_QUALIFIER + 'Type__c, ' +
                    PACKAGE_QUALIFIER + 'Merchant_Reference__c, ' +
                    PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__c, ' +
                    PACKAGE_QUALIFIER + 'Payment_Method__r.' + PACKAGE_QUALIFIER + 'Payment_Processor__r.' + PACKAGE_QUALIFIER + 'Type__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Payment_Activity__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Status__c = \'Pending\' ORDER BY CreatedDate LIMIT 2000';

        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        List<Payment_Activity__c> recToUpdate = new List<Payment_Activity__c>();
        try {
            List<Payment_Activity__c> stripePaymentActivities = new List<Payment_Activity__c>();
            List<Payment_Activity__c> cardknoxPaymentActivities = new List<Payment_Activity__c>();

            //collect all the cardknox and stripe type payment activities
            for(Payment_Activity__c activity : (List<Payment_Activity__c>)scope){
                if(activity.Payment_Method__r.Payment_Processor__r.Type__c == PaymentProcessorActions.CARDKNOX_TYPE){
                    cardknoxPaymentActivities.add(activity);
                }else if(activity.Payment_Method__r.Payment_Processor__r.Type__c == PaymentProcessorActions.STRIPE_TYPE){
                    stripePaymentActivities.add(activity);
                }
            }

            // use PaymentActivityUpdateUseCase to to update the cardknox type payment activities
            if(!cardknoxPaymentActivities.isEmpty()){
                PaymentActivityUpdateUseCase useCase = new PaymentActivityUpdateUseCase(gtwy);
                PaymentActivityUpdateUseCase.UpdateResult[] results = useCase.updatePaymentActivities(cardknoxPaymentActivities);
                handleResults(results);
            }
            //if found any stripe type activities update them here only
            if(!stripePaymentActivities.isEmpty()){
                List<Payment_Activity__c> activities = gtwy.getPaymentActivityStatus((List<Payment_Activity__c>) scope);
                //register the exception and response
                for (Payment_Activity__c activity : activities) {
                    if (activity.Status__c == STATUS_ERROR) {
                        registerStripeException(activity);
                        recToUpdate.add(activity);
                    } else {
                        registerResponse(activity);
                        recToUpdate.add(activity);
                    }
                }
            }
            if (!recToUpdate.isEmpty()) {
                SFDCSecurityUtils.updateProxy(recToUpdate);
            }
        }
        catch (Exception ex) {
            registerSystemException((List<Payment_Activity__c>) scope, ex);
        }
    }

    public void finish(Database.BatchableContext bc) {
        //void the cash receipt in salesforce
        startVoidProcess();
        sendStatistics();
    }

    /**
     * method to collect all the cash receipts that needs to be voided 
     * @param => PaymentActivityUpdateUseCase.UpdateResult[] list of all the updated 
     */
    private void handleResults(PaymentActivityUpdateUseCase.UpdateResult[] results) {
        for (PaymentActivityUpdateUseCase.UpdateResult result : results) {
            if (result.cashReceiptRequiresVoid) {
                voids.add(result.activity.Cash_Receipt__c);
            }
            registerResponse(result.activity);
        }
    }
    /**
     * Method to void cash receipts asynchronously using chain of the batches
     */
    private void startVoidProcess() {
        //return if voids are empty
        if (voids.isEmpty()) {
            return;
        }

        List<CashReceiptVoidHelper.VoidData> voidData = new List<CashReceiptVoidHelper.VoidData>();
        Date today = Date.today();
        // convert cash receipts ids to VoidData
        for (Id cr : voids) {
            CashReceiptVoidHelper.VoidData data = new CashReceiptVoidHelper.VoidData();
            data.cashReceiptId = cr;
            data.voidReceiptDate = today;
            data.description = Label.INF_AUTO_VOIDED_BY_MERCHANT_DOWNLOAD;
            voidData.add(data);
        }
        // create void service
        CashReceiptVoid voidService = new CashReceiptVoid();
        if (!Test.isRunningTest()) {
            // starts a batch chain to void CRs in salesforce
            voidService.asyncVoidCashReceiptInternally(voidData);
        }
    } 
    private void sendStatistics() {
        if (!AccountingSettingsHandler.isEmailConfirmationsDisabled()) {
            sendEmail(Label.INFO_PAYMENT_ACTIVITY_JOB_EMAIL_SUBJECT, buildMailBody());
        }
    }

    private void sendEmail(String emailSubject, String emailBody) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSubject(emailSubject);
        mail.setPlainTextBody(emailBody);

        List<Messaging.EmailFileAttachment> emailFileAttachments = new List<Messaging.EmailFileAttachment>();
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('PaymentActivityACHStatusCheckReport.csv');
        efa.setBody(Blob.valueOf(pReport.getCSV()));
        emailFileAttachments.add(efa);

        mail.setFileAttachments(emailFileAttachments);
        if (!Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
    }

    private String buildMailBody() {
        String emailTextBody =
            Label.INFO_PAYMENT_ACTIVITY_JOB_EMAIL_SUBJECT + '\n' +
            '\n\n' +
            Label.COMMON_TOTAL_NUMBER_RECORDS_PROCESSED + pReport.getCountProcessed() + '\n' +
            Label.COMMON_NUMBER_OF_SUCCESSFUL_PAYMENTS + pReport.getCountSucceeded() + '\n' +
            Label.COMMON_NUMBER_OF_DECLINED_PAYMENTS + pReport.getCountDeclined() + '\n' +
            Label.COMMON_NUMBER_OF_FAILED_PAYMENTS + pReport.getCountFailed() +
            '\n';

        if (pReport.getCountDeclined() > 0 || pReport.getCountFailed() > 0) {
            emailTextBody += Label.COMMON_LIST_DECLINED_RECORDS;
            List<ListView> views = DomainUtils.getListViews(
                new Set<String>{Payment_Activity__c.SObjectType.getDescribe().getName()},
                new List<String>{'ACH_Declined'}
            );
            if (!views.isEmpty()) {
                String fifteenCharsId = String.valueOf(views[0].Id).left(15);
                emailTextBody += URL.getOrgDomainUrl().toExternalForm() + '/' + Payment_Activity__c.SObjectType.getDescribe().getKeyPrefix() + '?fcf=' + fifteenCharsId;
            }
        }

        emailTextBody += '\n' + Label.INF_ATTACHED_CSV_RESULTS_PAYMENT_ACTIVITY_RECORDS;
        return emailTextBody;
    }

    private void registerStripeException(Payment_Activity__c paymentActivity) {
        pReport.addRow(
            new ProcessingReportRow(
                paymentActivity.Cash_Receipt__r.Name,
                paymentActivity.Name,
                String.valueOf(paymentActivity.Amount__c),
                paymentActivity.Status__c,
                paymentActivity.Error_Type__c,
                paymentActivity.Error_Message__c
            )
        );
    }

    private void registerSystemException(List<Payment_Activity__c> scope, Exception ex) {
        for (Payment_Activity__c paymentActivity : scope) {
            pReport.addRow(
                new ProcessingReportRow(
                    paymentActivity.Cash_Receipt__r.Name,
                    paymentActivity.Name,
                    String.valueOf(paymentActivity.Amount__c),
                    paymentActivity.Status__c,
                    Label.COMMON_SYSTEM_EXCEPTION,
                    ex.getMessage()
                )
            );
        }
    }

    private void registerResponse(Payment_Activity__c paymentActivity) {
        ProcessingReportRow newRow = new ProcessingReportRow(
            paymentActivity.Cash_Receipt__r.Name,
            paymentActivity.Name,
            String.valueOf(paymentActivity.Amount__c),
            paymentActivity.Status__c,
            paymentActivity.Error_Type__c,
            paymentActivity.Error_Message__c
        );
        pReport.addRow(newRow);
    }

    private with sharing class ProcessingReportRow {
        private String cashReceipt;
        private String paymentActivity;
        private String amount;
        private String status;
        private String errorCode;
        private String errorMessage;

        private ProcessingReportRow(String cashReceipt,
                                    String paymentActivity,
                                    String amount,
                                    String status,
                                    String errorCode,
                                    String errorMessage) {

            this.cashReceipt = cashReceipt;
            this.paymentActivity = paymentActivity;
            this.amount = amount;
            this.status = status;
            this.errorCode = errorCode;
            this.errorMessage = errorMessage;
        }
    }

    private with sharing class ProcessingReport {
        private Map<String, ProcessingReportRow> rowMap;
        private ProcessingReportRow headerRow;

        private ProcessingReport() {
            this.headerRow = new ProcessingReportRow(
                'Cash Receipt',
                'Payment',
                'Amount',
                'Status',
                'Error Code',
                'Error Message'
            );
            this.rowMap = new Map<String, ProcessingReportRow>();
        }

        private void addRow(ProcessingReportRow newRow) {
            this.rowMap.put(newRow.paymentActivity, newRow);
        }

        private String getCSV() {
            String result = headerRow.cashReceipt + ',' +
                headerRow.paymentActivity + ',' +
                headerRow.amount + ',' +
                headerRow.status + ',' +
                headerRow.errorCode + ',' +
                headerRow.errorMessage + '\r\n';

            for (ProcessingReportRow row : rowMap.values()) {
                List<String> fields = new List<String>();
                fields.add(row.cashReceipt);
                fields.add(row.paymentActivity);
                fields.add(row.amount);
                fields.add(row.status);
                fields.add(row.errorCode);
                fields.add(row.errorMessage);

                result += String.join(fields, ',') + '\r\n';
            }
            return result;
        }

        private Integer getCountProcessed() {
            return rowMap.size();
        }

        private Integer getCountSucceeded() {
            return getCountByStatus('Success');
        }

        private Integer getCountDeclined() {
            return getCountByStatus('Declined');
        }

        private Integer getCountFailed() {
            return getCountByStatus('Error');
        }

        private Integer getCountByStatus(String status) {
            Integer result = 0;
            for (ProcessingReportRow row : rowMap.values()) {
                if (row.status == status) {
                    result++;
                }
            }
            return result;
        }
    }

}