public with sharing class ArchiveAndDeleteTransactionsBatch implements Database.Batchable<sObject>, Database.Stateful {

    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static Boolean IS_ERP_ENABLED = AccountingSettingsHandler.isERPEnabled();

    private Accounting_Period__c acctPeriod;
    @TestVisible
    private String transactionQuery;
    private String errorMessage;
    @TestVisible
    private Boolean isError;
    private class DeleteTransactionException extends Exception {}

    public ArchiveAndDeleteTransactionsBatch(Accounting_Period__c period) {
        this.acctPeriod = period;
        this.isError = false;
        this.transactionQuery =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Account__c, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Year__c, ' +
                    PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c, ' +
                    PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                    PACKAGE_QUALIFIER + 'AP_Disbursement__c, ' +
                    PACKAGE_QUALIFIER + 'AP_Disbursement__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__c, ' +
                    PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Billing__c, ' +
                    PACKAGE_QUALIFIER + 'Billing__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Billing_Line__c, ' +
                    PACKAGE_QUALIFIER + 'Billing_Line__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Cash_Disbursement__c, ' +
                    PACKAGE_QUALIFIER + 'Cash_Disbursement__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Cash_Flow_Category__c, ' +
                    PACKAGE_QUALIFIER + 'Cash_Receipt__c, ' +
                    PACKAGE_QUALIFIER + 'Cash_Receipt__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Contact__c, ' +
                    PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c, ' +
                    PACKAGE_QUALIFIER + 'Date__c, ' +
                    PACKAGE_QUALIFIER + 'Employee__c, ' +
                    PACKAGE_QUALIFIER + 'Foreign_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Foreign_Currency__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Type__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c, ' +
                    PACKAGE_QUALIFIER + 'Journal_Entry_Line__c, ' +
                    PACKAGE_QUALIFIER + 'Journal_Entry_Line__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Ledger__c, ' +
                    PACKAGE_QUALIFIER + 'Note__c, ' +
                    PACKAGE_QUALIFIER + 'Account_Payable__c, ' +
                    PACKAGE_QUALIFIER + 'Account_Payable__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Account_Payable_Line__c, ' +
                    PACKAGE_QUALIFIER + 'Account_Payable_Line__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Product__c, ' +
                    PACKAGE_QUALIFIER + 'Project__c, ' +
                    PACKAGE_QUALIFIER + 'Project_Task__c, ' +
                    PACKAGE_QUALIFIER + 'Units__c, ' +
                    PACKAGE_QUALIFIER + 'Report_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Time_Card_Day__c, ' +
                    PACKAGE_QUALIFIER + 'Time_Card_Day__r.Name, ' +
                    PACKAGE_QUALIFIER + 'Time_Card_Variable_1__c, ' +
                    PACKAGE_QUALIFIER + 'Time_Card_Variable_2__c ' +
                    ((IS_ERP_ENABLED)
                        ?   ', AcctSeedERP__Inbound_Inventory_Movement__c, ' +
                            'AcctSeedERP__Inbound_Inventory_Movement__r.Name, ' +
                            'AcctSeedERP__Outbound_Inventory_Movement__c, ' +
                            'AcctSeedERP__Outbound_Inventory_Movement__r.Name, ' +
                            'AcctSeedERP__Sales_Order_Inventory_Movement__c, ' +
                            'AcctSeedERP__Sales_Order_Inventory_Movement__r.Name, ' +
                            'AcctSeedERP__Purchase_Order_Inventory_Movement__c, ' +
                            'AcctSeedERP__Purchase_Order_Inventory_Movement__r.Name, ' +
                            'AcctSeedERP__Manufacturing_Inventory_Movement__c, ' +
                            'AcctSeedERP__Manufacturing_Inventory_Movement__r.Name '
                        :   '') +
            'FROM ' + PACKAGE_QUALIFIER + 'Transaction__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = \'' + acctPeriod.Id + '\' ' +
            'ORDER BY ' + PACKAGE_QUALIFIER + 'GL_Account__r.Name ASC';
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(transactionQuery);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        Savepoint sp;
        try {
            List<SObject> archiveList = cloneTransactions(scope);
            if (!Test.isRunningTest() && !archiveList.isEmpty()) {
                List<Database.SaveResult> srList = Database.insertImmediate(archiveList);
                if (sanityCheck(scope, archiveList)) {
                    sp = Database.setSavepoint();
                    TransactionActions.isPreventDeleteOverride = true;
                    SFDCSecurityUtils.deleteProxy(scope);
                    TransactionActions.isPreventDeleteOverride = false;
                }
                else {
                    throw new DeleteTransactionException(
                        Label.ERR_SANITY_CHECK_TRANSACTIONS_DELETED
                    );
                }
            }
        }
        catch (Exception ex) {
            errorMessage = ex.getMessage();
            isError = true;
            if (sp != NULL) {
                Database.rollback(sp);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            if (!isError) {
                AccountingPeriodOpenCloseUtils.updateAndNotify(
                    acctPeriod,
                    AccountingPeriodActions.ARCHIVED_STATUS,
                    AccountingPeriodOpenCloseUtils.ARCHIVE_SUCCESSFUL_EMAIL_SUBJECT,
                    String.format(AccountingPeriodOpenCloseUtils.ARCHIVE_SUCCESSFUL_EMAIL_BODY, new List<String>{acctPeriod.Name})
                );
            }
            else {
                throw new DeleteTransactionException(errorMessage);
            }
        }
        catch (Exception ex) {
            notifyUser(
                String.format(AccountingPeriodOpenCloseUtils.ARCHIVE_FAILED_EMAIL_SUBJECT, new List<String>{acctPeriod.Name}),
                String.format(AccountingPeriodOpenCloseUtils.ARCHIVE_FAILED_EMAIL_BODY, new List<String>{acctPeriod.Name, ex.getMessage()})
            );
        }
    }

    @TestVisible
    private Boolean sanityCheck(List<Transaction__c> sourceTransactions, List<Transaction_Archive__b> archivedTransactions) {
        Boolean result = true;
        //before the deletion we should do a sanity check
        //Regular Transactions can have up to 2 archived transactions(for period and for cash flow)
        //First we will get mapping for existed Transactions and related Financial Cube Transactions
        Map<Id, List<Financial_Cube_Transaction__c>> transactionToJunctionMap = getFinancialCubeTransactions(sourceTransactions);
        //now we will check archived transactions were created
        for (Transaction__c sourceTransaction : sourceTransactions) {
            Integer numberOfArchivedTransactions = 0;
            for (Transaction_Archive__b archivedTransaction : archivedTransactions) {
                if (archivedTransaction.Transaction_Id__c == sourceTransaction.Id) {
                    numberOfArchivedTransactions++;
                }
            }
            //there must be either 1 archived transaction for regular Period Transaction
            //or 2 in case of Cash Flow Statement related Transaction
            if (transactionToJunctionMap.get(sourceTransaction.Id).size() != numberOfArchivedTransactions) {
                result = false;
                break;
            }
        }
        return result;
    }

    private Map<Id, List<Financial_Cube_Transaction__c>> getFinancialCubeTransactions(List<Transaction__c> sourceTransactions) {
        List<Financial_Cube_Transaction__c> financialCubeTransactions =
            DomainUtils.getFinancialCubeTransactionsByTransaction(sourceTransactions);

        Map<Id, List<Financial_Cube_Transaction__c>> transactionToJunctionMap = new Map<Id, List<Financial_Cube_Transaction__c>>();
        for (Financial_Cube_Transaction__c eachJunctionRecord : financialCubeTransactions) {
            if (transactionToJunctionMap.containsKey(eachJunctionRecord.Transaction__c)) {
                transactionToJunctionMap.get(eachJunctionRecord.Transaction__c).add(eachJunctionRecord);
            }
            else {
                transactionToJunctionMap.put(
                    eachJunctionRecord.Transaction__c,
                    new List<Financial_Cube_Transaction__c>{eachJunctionRecord}
                );
            }
        }

        return transactionToJunctionMap;
    }

    @TestVisible
    private List<SObject> cloneTransactions(List<Transaction__c> sourceTransactions) {
        List<Transaction_Archive__b> targetTransactions = new List<Transaction_Archive__b>();
        //query Financial_Cube_Transaction__c
        Map<Id, List<Financial_Cube_Transaction__c>> transactionToJunctionMap = getFinancialCubeTransactions(sourceTransactions);

        for (Transaction__c sourceTrans : sourceTransactions) {
            for (Financial_Cube_Transaction__c fcTransaction : transactionToJunctionMap.get(sourceTrans.Id)) {
                Transaction_Archive__b tempTargetTransaction = new Transaction_Archive__b();
                tempTargetTransaction.AP_Disbursement__c = sourceTrans.AP_Disbursement__c;
                tempTargetTransaction.Account__c = sourceTrans.Account__c;
                tempTargetTransaction.Accounting_Period__c = sourceTrans.Accounting_Period__c;
                tempTargetTransaction.Accounting_Year__c = sourceTrans.Accounting_Year__c;
                tempTargetTransaction.Amortization_Entry__c = sourceTrans.Scheduled_Revenue_Expense__c;
                tempTargetTransaction.Amount__c = sourceTrans.Amount__c;
                tempTargetTransaction.Billing_Cash_Receipt__c = sourceTrans.Billing_Cash_Receipt__c;
                tempTargetTransaction.Billing__c = sourceTrans.Billing__c;
                tempTargetTransaction.Billing_Line__c = sourceTrans.Billing_Line__c;
                tempTargetTransaction.Cash_Disbursement__c = sourceTrans.Cash_Disbursement__c;
                tempTargetTransaction.Cash_Flow_Category__c = sourceTrans.Cash_Flow_Category__c;
                tempTargetTransaction.Cash_Receipt__c = sourceTrans.Cash_Receipt__c;
                tempTargetTransaction.Contact__c = sourceTrans.Contact__c;
                tempTargetTransaction.Currency_Conversion_Rate__c = sourceTrans.Currency_Conversion_Rate__c;
                tempTargetTransaction.Date__c = sourceTrans.Date__c;
                tempTargetTransaction.Employee__c = sourceTrans.Employee__c;
                tempTargetTransaction.Financial_Cube__c = fcTransaction.Financial_Cube__c;
                tempTargetTransaction.Financial_Cube_Type__c = fcTransaction.Financial_Cube__r.Cube_Type__c;
                tempTargetTransaction.Foreign_Amount__c = sourceTrans.Foreign_Amount__c;
                tempTargetTransaction.Foreign_Currency__c = sourceTrans.Foreign_Currency__c;
                tempTargetTransaction.GL_Account_Type__c = sourceTrans.GL_Account_Type__c;
                tempTargetTransaction.GL_Account_Variable_1__c = sourceTrans.GL_Account_Variable_1__c;
                tempTargetTransaction.GL_Account_Variable_2__c = sourceTrans.GL_Account_Variable_2__c;
                tempTargetTransaction.GL_Account_Variable_3__c = sourceTrans.GL_Account_Variable_3__c;
                tempTargetTransaction.GL_Account_Variable_4__c = sourceTrans.GL_Account_Variable_4__c;
                tempTargetTransaction.GL_Account__c = sourceTrans.GL_Account__c;
                tempTargetTransaction.Journal_Entry_Line__c = sourceTrans.Journal_Entry_Line__c;
                tempTargetTransaction.Ledger__c = sourceTrans.Ledger__c;
                tempTargetTransaction.Note__c = sourceTrans.Note__c;
                tempTargetTransaction.Payable__c = sourceTrans.Account_Payable__c;
                tempTargetTransaction.Payable_Line__c = sourceTrans.Account_Payable_Line__c;
                tempTargetTransaction.Product__c = sourceTrans.Product__c;
                tempTargetTransaction.Project_Task__c = sourceTrans.Project_Task__c;
                tempTargetTransaction.Project__c = sourceTrans.Project__c;
                tempTargetTransaction.Quantity__c = sourceTrans.Units__c;
                tempTargetTransaction.Report_Amount__c = sourceTrans.Report_Amount__c;
                tempTargetTransaction.Time_Card_Day__c = sourceTrans.Time_Card_Day__c;
                tempTargetTransaction.Time_Card_Variable_1__c = sourceTrans.Time_Card_Variable_1__c;
                tempTargetTransaction.Time_Card_Variable_2__c = sourceTrans.Time_Card_Variable_2__c;
                tempTargetTransaction.Transaction_Id__c = sourceTrans.Id;

                if (IS_ERP_ENABLED) {
                    tempTargetTransaction.put(
                        'AcctSeedERP__Inbound_Inventory_Movement__c',
                        (Id) sourceTrans.get('AcctSeedERP__Inbound_Inventory_Movement__c')
                    );
                    tempTargetTransaction.put(
                        'AcctSeedERP__Outbound_Inventory_Movement__c',
                        (Id) sourceTrans.get('AcctSeedERP__Outbound_Inventory_Movement__c')
                    );
                    tempTargetTransaction.put(
                        'AcctSeedERP__Sales_Order_Inventory_Movement__c',
                        (Id) sourceTrans.get('AcctSeedERP__Sales_Order_Inventory_Movement__c')
                    );
                    tempTargetTransaction.put(
                        'AcctSeedERP__Purchase_Order_Inventory_Movement__c',
                        (Id) sourceTrans.get('AcctSeedERP__Purchase_Order_Inventory_Movement__c')
                    );
                    tempTargetTransaction.put(
                        'AcctSeedERP__Manufacturing_Inventory_Movement__c',
                        (Id) sourceTrans.get('AcctSeedERP__Manufacturing_Inventory_Movement__c')
                    );
                }

                tempTargetTransaction.Source_Name__c = getSourceName(sourceTrans);

                targetTransactions.add(tempTargetTransaction);
            }
        }
        return targetTransactions;
    }

    private String getSourceName(Transaction__c trans) {
        String result;
        if (trans.AP_Disbursement__c != NULL) {
            result = trans.AP_Disbursement__r.Name;
        }
        else if (trans.Billing__c != NULL) {
            result = trans.Billing__r.Name;
        }
        else if (trans.Billing_Line__c != NULL) {
            result = trans.Billing_Line__r.Name;
        }
        else if (trans.Account_Payable__c != NULL) {
            result = trans.Account_Payable__r.Name;
        }
        else if (trans.Account_Payable_Line__c != NULL) {
            result = trans.Account_Payable_Line__r.Name;
        }
        else if (trans.Cash_Receipt__c != NULL) {
            result = trans.Cash_Receipt__r.Name;
        }
        else if (trans.Cash_Disbursement__c != NULL) {
            result = trans.Cash_Disbursement__r.Name;
        }
        else if (trans.Journal_Entry_Line__c != NULL) {
            result = trans.Journal_Entry_Line__r.Name;
        }
        else if (trans.Billing_Cash_Receipt__c != NULL) {
            result = trans.Billing_Cash_Receipt__r.Name;
        }
        else if (trans.Time_Card_Day__c != NULL) {
            result = trans.Time_Card_Day__r.Name;
        }
        else if (trans.Scheduled_Revenue_Expense__c != NULL) {
            result = trans.Scheduled_Revenue_Expense__r.Name;
        }

        if (IS_ERP_ENABLED && result == NULL) {
            if (trans.get('AcctSeedERP__Inbound_Inventory_Movement__c') != NULL) {
                result = (String) trans.getSObject('AcctSeedERP__Inbound_Inventory_Movement__r').get('Name');
            }
            else if (trans.get('AcctSeedERP__Outbound_Inventory_Movement__c') != NULL) {
                result = (String) trans.getSObject('AcctSeedERP__Outbound_Inventory_Movement__r').get('Name');
            }
            else if (trans.get('AcctSeedERP__Sales_Order_Inventory_Movement__c') != NULL) {
                result = (String) trans.getSObject('AcctSeedERP__Sales_Order_Inventory_Movement__r').get('Name');
            }
            else if (trans.get('AcctSeedERP__Purchase_Order_Inventory_Movement__c') != NULL) {
                result = (String) trans.getSObject('AcctSeedERP__Purchase_Order_Inventory_Movement__r').get('Name');
            }
            else if (trans.get('AcctSeedERP__Manufacturing_Inventory_Movement__c') != NULL) {
                result = (String) trans.getSObject('AcctSeedERP__Manufacturing_Inventory_Movement__r').get('Name');
            }
        }

        return result;
    }

    private void notifyUser(String mailSubject, String mailBody) {
        try {
            if (FinancialSuiteUtils.canSendEmail()) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                String[] toAddresses = new String[] {UserInfo.getUserEmail()};
                mail.setToAddresses(toAddresses);
                mail.setSubject(mailSubject);
                mail.setPlainTextBody(mailBody);
                if (!Test.isRunningTest()) {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

}