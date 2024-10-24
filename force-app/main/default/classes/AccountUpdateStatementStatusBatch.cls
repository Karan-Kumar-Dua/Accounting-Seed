public with sharing class AccountUpdateStatementStatusBatch implements Database.Stateful, Database.Batchable<SObject> {

    public static final String REPORT_SUBJECT = Label.INF_CUSTOMER_UPDATE_REPORT_SUBJECT;
    public static final String EMAIL_MESSAGE = Label.INF_CUSTOMER_UPDATE_EMAIL_MESSAGE;

    private Set<Id> accountsIds;

    public AccountUpdateStatementStatusBatch(Set<Id> ids) {
        accountsIds = ids;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Last_Statement_Sent__c, Statement_Needed__c FROM Account WHERE Id IN :accountsIds';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Account> accounts = (List<Account>) scope;

        Map<Id, List<Billing__c>> billingMap = new Map<Id, List<Billing__c>>();
        for (Billing__c bill : (List<Billing__c>) Database.query(
                'SELECT Id, Customer__c, Balance__c, Status__c FROM Billing__c WHERE Customer__c IN :accounts AND Status__c = \'Posted\'')) {

            if (billingMap.containsKey(bill.Customer__c)) {
                billingMap.get(bill.Customer__c).add(bill);
            }
            else {
                billingMap.put(bill.Customer__c, new List<Billing__c>{bill});
            }
        }

        for (Account account : accounts) {
            if (!billingMap.containsKey(account.Id)) {
                account.Statement_Needed__c = 'No';
                continue;
            }
            Decimal balance = 0;
            for (Billing__c bill : billingMap.get(account.Id)) {
                balance += bill.Balance__c;
            }
            if (balance > 0) {
                account.Statement_Needed__c = 'Yes';
            }
            else {
                account.Statement_Needed__c = 'No';
            }
        }
        SFDCSecurityUtils.updateProxy(accounts);
    }

    public void finish (Database.BatchableContext BC) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String> {UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSubject(REPORT_SUBJECT);
        mail.setPlainTextBody(EMAIL_MESSAGE);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
    }

}