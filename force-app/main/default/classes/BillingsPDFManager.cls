public with sharing class BillingsPDFManager extends AbstractStatementManager {
   
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER.replaceAll('_', '');
    public static final String NO_SENDER_EMAIL_ERROR = Label.ERR_MISSING_BILLING_CONTACT_NO_MAIL;

    public static final String REPORT_LOG_TEMPLATE_LINE =
        'Billing Number: ' + AbstractStatementManager.REPORT_LOG_SOURCE_NMB +
            ' Error: ' + AbstractStatementManager.REPORT_LOG_SOURCE_DESC + '\r\n';

    public List<Billing__c> bills {get; private set;}
    public Boolean isNoSelectedBills {get; private set;}
    public Boolean isMissContact {get; private set;}
    public Boolean isAllMiss {get; private set;}
    private ApexPages.StandardSetController setController;


    public BillingsPDFManager(ApexPages.StandardSetController setController) {
        try {
            this.setController = setController;
            initBillings();
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    public PageReference savePDFs() {
        return callingBatch(false);
    }

    public PageReference emailPDFs() {
        return callingBatch(true);
    }

    private PageReference callingBatch(Boolean isMailing) {
        List<Id> selectedIds = new List<Id>();
        String resultMessage;

        for (Billing__c bill : bills) {
            if (!isMailing
                    || (isMailing
                            && bill.Billing_Contact__c != NULL
                            && bill.Billing_Contact__r.Email != NULL)) {

                selectedIds.add(bill.Id);
            }
        }

        if (isMailing) {
            try {
                Messaging.reserveSingleEmailCapacity(selectedIds.size());
            }
            catch (Exception ex) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, EMAIL_LIMIT_ERROR));
                return NULL;
            }
            resultMessage = MAIL_SUCCESS_MESSAGE_FOR_BILLINGS;
        }
        else {
            resultMessage = ATTACH_SUCCESS_MESSAGE_FOR_BILLINGS;
        }

        StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
                selectedIds,
                isMailing,
                FinancialSuiteUtils.currentRequestBaseUrl(),
                StatementBase.BILLING
        );
        Database.executeBatch(pdfBatch, BATCH_CHUNK_SIZE);

        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, resultMessage));
        return NULL;
    }

    private void initBillings() {
        isNoSelectedBills = false;
        this.bills = DomainUtils.getBillingsBySelectedBillings((List<Billing__c>) setController.getSelected());

        if (this.bills.isEmpty()) {
            isNoSelectedBills = true;
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    AbstractStatementManager.NO_RECORDS_SELECTED_ERROR
                )
            );
        }
        else {
            isMissContact = false;
            isAllMiss = true;
            for (Billing__c bill : this.bills) {
                if (!isMissContact && (bill.Billing_Contact__c == NULL || bill.Billing_Contact__r.Email == NULL)) {
                    isMissContact = true;
                }
                if (isAllMiss && (bill.Billing_Contact__c != NULL && bill.Billing_Contact__r.Email != NULL)) {
                    isAllMiss = false;
                }
            }
            if (isMissContact) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.WARNING,
                        BillingsPDFManager.NO_SENDER_EMAIL_ERROR
                    )
                );
            }
        }
    }
}