public with sharing class TransactionActions {

    private static final Boolean ERP_ENABLED = AccountingSettingsHandler.isERPEnabled();
    private static Boolean isTransactionERPFieldsExist;
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    private static final String ORIGINAL_STATE_VALIDATION_ERROR =
        Label.ERR_ORIGINAL_STATE_VALIDATION;
    public static final String INSERT_ERROR = Label.ERR_INSERT_TRANSACTION; 
    public static final String DELETE_ERROR = Label.ERR_DELETE_TRANSACTION;  
    public static final String UPDATE_ERROR = Label.ERR_UPDATE_TRANSACTION;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Transaction__c.Amount__c => 2,
        Transaction__c.Foreign_Amount__c => 2
    };

    public static final List<SObjectField> fsSourceDocumentFields = new List<SObjectField> {
        Transaction__c.Account_Payable__c,
        Transaction__c.Account_Payable_Line__c,
        Transaction__c.Billing_Cash_Receipt__c,
        Transaction__c.Billing__c,
        Transaction__c.Billing_Line__c,
        Transaction__c.Cash_Disbursement__c,
        Transaction__c.Cash_Receipt__c,
        Transaction__c.Journal_Entry_Line__c,
        Transaction__c.Scheduled_Revenue_Expense__c,
        Transaction__c.Time_Card_Day__c,
        Transaction__c.AP_Disbursement__c
    };
    public static final List<SObjectField> erpSourceDocumentFields = new List<SObjectField> {
        FinancialSuiteUtils.getSObjectFieldToken(Transaction__c.SObjectType, ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c'),
        FinancialSuiteUtils.getSObjectFieldToken(Transaction__c.SObjectType, ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c'),
        FinancialSuiteUtils.getSObjectFieldToken(Transaction__c.SObjectType, ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c'),
        FinancialSuiteUtils.getSObjectFieldToken(Transaction__c.SObjectType, ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c'),
        FinancialSuiteUtils.getSObjectFieldToken(Transaction__c.SObjectType, ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c')
    };
    public static final String ONE_SOURCE_DOCUMENT_ERROR = Label.INF_TRANSACTION_RECORD_ONE_SD_LOOKUP_POPULATED;
    private static Set<SObjectField> lockedDownOnInsertFields {
        get {
            Set<SObjectField> result = new Set<SObjectField>{
                Transaction__c.GL_Account__c,
                Transaction__c.GL_Account_Variable_1__c,
                Transaction__c.GL_Account_Variable_2__c,
                Transaction__c.GL_Account_Variable_3__c,
                Transaction__c.GL_Account_Variable_4__c,
                Transaction__c.Ledger__c,
                Transaction__c.Accounting_Period__c,
                Transaction__c.Amount__c,
                Transaction__c.Billing_Line__c,
                Transaction__c.Account_Payable_Line__c,
                Transaction__c.Billing__c,
                Transaction__c.Account_Payable__c,
                Transaction__c.Journal_Entry_Line__c,
                Transaction__c.Scheduled_Revenue_Expense__c,
                Transaction__c.Cash_Receipt__c,
                Transaction__c.Billing_Cash_Receipt__c,
                Transaction__c.AP_Disbursement__c,
                Transaction__c.Cash_Disbursement__c
            };
            if (ERP_ENABLED) {
                //sometimes in test context this flag will be set to true even if there is no ERP package installed
                SObjectField mim = SchemaDescribe.getDescribe(Transaction__c.SObjectType).getField(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c');
                if (mim != NULL) {result.add(mim);}
                SObjectField iim = SchemaDescribe.getDescribe(Transaction__c.SObjectType).getField(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c');
                if (mim != NULL) {result.add(iim);}
                SObjectField oim = SchemaDescribe.getDescribe(Transaction__c.SObjectType).getField(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c');
                if (mim != NULL) {result.add(oim);}
                SObjectField poim = SchemaDescribe.getDescribe(Transaction__c.SObjectType).getField(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c');
                if (mim != NULL) {result.add(poim);}
                SObjectField soim = SchemaDescribe.getDescribe(Transaction__c.SObjectType).getField(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c');
                if (mim != NULL) {result.add(soim);}
            }
            return result;
        }
    }

    @TestVisible
    private static List<Transaction__c> originalRecords;

    public static Boolean isPreventUpdateOverride = false;
    public static Boolean isPreventInsertOverride = false;
    public static Boolean isPreventDeleteOverride = false;

    public static void preventTransactionDelete(List<Transaction__c> transactions) {
        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        if (main.Financial_Suite_Key__c != NULL
                && main.Financial_Suite_Key__c == EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_UPDATE_DELETE_KEY)))) {

            isPreventDeleteOverride = true;
        }

        List<SObjectField> fieldList = fsSourceDocumentFields;

        if (ERP_ENABLED && isTransactionERPFieldsExist()) {
            fieldList.addAll(erpSourceDocumentFields);
        }

        for (Transaction__c tran : transactions) {
            if (isPreventDeleteOverride || isOrphaned(tran, fieldList)) {
                break;
            }

            tran.addError(DELETE_ERROR, false);
        }  
    }

    public static List<Transaction__c> queryTransactions(List<SObject> sourceDocuments) {
        return queryTransactions(sourceDocuments, false);
    }

    // This will not work for partial processing of deleting records. It should work correctly in that context
    public static List<Transaction__c> queryTransactions(List<SObject> sourceDocuments, Boolean isHeaderLevelPostingEnabled) {
        return queryTransactions(sourceDocuments, isHeaderLevelPostingEnabled, null);
    }
    public static List<Transaction__c> queryTransactions(List<SObject> sourceDocuments, Boolean isHeaderLevelPostingEnabled, Integer recordsLimit) {
        List<Transaction__c> transactions = new List<Transaction__c>();

        if (sourceDocuments != NULL && !sourceDocuments.isEmpty()) {
            String predicate;
            Set<Id> headerIds = new Set<Id>();

            try {
                switch on sourceDocuments[0] {
                    when Billing_Line__c objRecord {
                        predicate = '(' + Billing_Line__c.getSObjectType() + ' IN :sourceDocuments AND '
                            + Billing_Cash_Receipt__c.getSObjectType() + ' = null) ';
                        if (isHeaderLevelPostingEnabled) {
                            for (SObject doc : sourceDocuments) {
                                headerIds.add((Id) doc.get(Billing_Line__c.Billing__c));
                            }
                            predicate += ' OR (' + Billing__c.getSObjectType() + ' IN :headerIds AND '
                                + Billing_Cash_Receipt__c.getSObjectType() + ' = null) ';
                        }
                    }
                    when Account_Payable_Line__c objRecord {
                        predicate = '(' + Account_Payable_Line__c.getSObjectType() + ' IN :sourceDocuments AND '
                            + AP_Disbursement__c.getSObjectType() + ' = null) ';
                        if (isHeaderLevelPostingEnabled) {
                            for (SObject doc : sourceDocuments) {
                                headerIds.add((Id) doc.get(Account_Payable_Line__c.Account_Payable__c));
                            }
                            predicate += ' OR (' + Account_Payable__c.getSObjectType() + ' IN :headerIds AND '
                                + AP_Disbursement__c.getSObjectType() + ' = null) ';
                        }
                    }
                    when Time_Card_Day__c objRecord {
                        predicate = Time_Card_Day__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when Journal_Entry_Line__c objRecord {
                        predicate = Journal_Entry_Line__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when Scheduled_Revenue_Expense__c objRecord {
                        predicate = Scheduled_Revenue_Expense__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when Cash_Disbursement__c objRecord {
                        predicate = Cash_Disbursement__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when Cash_Receipt__c objRecord {
                        predicate = Cash_Receipt__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when AP_Disbursement__c objRecord {
                        predicate = AP_Disbursement__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when Billing_Cash_Receipt__c objRecord {
                        predicate = Billing_Cash_Receipt__c.getSObjectType() + ' IN :sourceDocuments';
                    }
                    when Transaction__c objRecord {
                        predicate = 'Id IN :sourceDocuments';
                    }
                }
                transactions = (List<Transaction__c>) Database.query(
                    'SELECT Id FROM ' + Transaction__c.getSObjectType() + ' WHERE ' + predicate + (recordsLimit != null ? ' LIMIT :recordsLimit' : '')
                );
            }
            catch (Exception ex) {
                throw ex;
            }
        }

        return transactions;
    }

    public static void requireFields(Transaction__c[] transactions) {
        for (Transaction__c tr : transactions) {
            if (tr.Ledger__c == NULL) {
                tr.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (tr.Accounting_Period__c == NULL) {
                tr.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (tr.GL_Account__c == NULL) {
                tr.GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setTransactionKey(List<Transaction__c> transactions) {
        for (Transaction__c tr : transactions) {
            if (String.isBlank(tr.Transaction_Key__c)) {
                TransactionKey tk = new TransactionKey(tr);
                tr.Transaction_Key__c = tk.hashCode();
            }
        }
    }

    public static void deleteTransactions(List<Transaction__c> transactions) {
        isPreventDeleteOverride = true;
        SFDCSecurityUtils.deleteProxy(transactions);
        isPreventDeleteOverride = false;
    }

    public static void createTransactions(List<Transaction__c> transactions) {
        SObjectActions.normalizeNumericAndCurrencyFields(transactions, TransactionActions.currencyAndNumberFields);
        isPreventInsertOverride = true;
        triggerChunkNmb = 0;
        originalRecords = transactions;
        SFDCSecurityUtils.insertProxy(transactions);
        isPreventInsertOverride = false;
    }

    public static void validateOriginalState(List<Transaction__c> newTransactions) {
        Integer startIndex = triggerChunkNmb * 200;
        originalRecords = originalRecords != NULL ? originalRecords : newTransactions;
        for (Integer i = startIndex; i < (startIndex + newTransactions.size()); i++) {
            compareTransactions(originalRecords.get(i), newTransactions.get(i - startIndex));
        }
        triggerChunkNmb++;
    }

    @TestVisible
    private static Integer triggerChunkNmb = 0;

    private static void compareTransactions(Transaction__c origT, Transaction__c newT) {
        Map<String, Object> populatedFieldsOnOriginalRecord = origT.getPopulatedFieldsAsMap();

        for (SObjectField sField : lockedDownOnInsertFields) {
            if (!populatedFieldsOnOriginalRecord.containsKey(sField.getDescribe().getName())) {
                continue;
            }
            else if (origT.get(sField) != newT.get(sField)) {
                newT.addError(
                    String.format(
                        ORIGINAL_STATE_VALIDATION_ERROR,
                        new List<Object>{
                            sField.getDescribe().getLabel(),
                            origT.get(sField),
                            newT.get(sField)
                        }
                    )
                );
                break;
            }
        }
    }

    public static void preventTransactionInsert(List<Transaction__c> transactions) {
        for (Transaction__c tran : transactions) {

            if (isPreventInsertOverride) {
                break;
            }

            tran.addError(INSERT_ERROR);
        }
    }

    public static void updateTransaction(Map<Id, Transaction__c> oldTransMap, Map<Id, Transaction__c> newTransMap) {
        List<Transaction__c> transList = new List<Transaction__c>();

        for (Transaction__c trans : newTransMap.values()) {
            if (trans.Ledger__c == NULL) {
                transList.add(trans);
            }
        }

        for (Financial_Cube_Transaction__c fct : DomainUtils.getFinancialCubeTransactionsByTransaction(transList)) {
            if (newTransMap.containsKey(fct.Transaction__c)) {
                newTransMap.get(fct.Transaction__c).Ledger__c = fct.Financial_Cube__r.Ledger__c;
            }
        }
    }

    public static void preventTransactionUpdate(Map<Id, Transaction__c> oldTransMap, Map<Id, Transaction__c> newTransMap) {
        Accounting_Settings__c main;

        List<SObjectField> nonUpdateableFields = new List<SObjectField> {
            Transaction__c.Account__c,
            Transaction__c.Accounting_Period__c,
            Transaction__c.Account_Payable__c,
            Transaction__c.Account_Payable_Line__c,
            Transaction__c.Amount__c,
            Transaction__c.Billing_Cash_Receipt__c,
            Transaction__c.Billing__c,
            Transaction__c.Billing_Line__c,
            Transaction__c.Cash_Disbursement__c,
            Transaction__c.Cash_Receipt__c,
            Transaction__c.Date__c,
            Transaction__c.Employee__c,
            Transaction__c.Contact__c,
            Transaction__c.Cash_Flow_Category__c,
            Transaction__c.GL_Account__c,
            Transaction__c.GL_Account_Variable_1__c,
            Transaction__c.GL_Account_Variable_2__c,
            Transaction__c.GL_Account_Variable_3__c,
            Transaction__c.GL_Account_Variable_4__c,
            Transaction__c.Journal_Entry_Line__c,
            Transaction__c.Product__c,
            Transaction__c.Project__c,
            Transaction__c.Project_Task__c,
            Transaction__c.Units__c,
            Transaction__c.Scheduled_Revenue_Expense__c,
            Transaction__c.Time_Card_Day__c,
            Transaction__c.Time_Card_Variable_1__c,
            Transaction__c.Time_Card_Variable_2__c,
            Transaction__c.Foreign_Amount__c,
            Transaction__c.Foreign_Currency__c,
            Transaction__c.Currency_Conversion_Rate__c,
            Transaction__c.AP_Disbursement__c
        };

        if (ERP_ENABLED && isTransactionERPFieldsExist()) {
            nonUpdateableFields.addAll(erpSourceDocumentFields);
        }

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            nonUpdateableFields.add(Transaction__c.SObjectType.getDescribe().fields.getMap().get('CurrencyIsoCode'));
        }

        try {
            main = AccountingSettingsHandler.getAccountingSettings();

            if (main.Financial_Suite_Key__c != NULL
                    && main.Financial_Suite_Key__c == EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.TRANSACTION_UPDATE_DELETE_KEY)))) {

                isPreventUpdateOverride = true;
            }
        }
        catch (QueryException ex) {

        }

        for (Transaction__c newTran : newTransMap.values()) {
            if (isPreventUpdateOverride) {
                break;
            }

            Transaction__c oldTran = oldTransMap.get(newTran.Id);

            for (SObjectField fieldToken : nonUpdateableFields) {
                if (FinancialSuiteUtils.isFieldValueChanged(fieldToken, oldTran, newTran)) {
                    newTran.addError(UPDATE_ERROR, false);
                    break;
                }
            }

            if (oldTran.Ledger__c != NULL && oldTran.Ledger__c != newTran.Ledger__c) {
                newTran.addError(UPDATE_ERROR, false);
            }
        }

        nonUpdateableFields.add(Transaction__c.Ledger__c);
    }

    @TestVisible
    private static Boolean isOrphaned(Transaction__c tran, List<SObjectField> fieldList) {
        Boolean isOrphaned = true;

        for (SObjectField field : fieldList) {
            if (tran.get(field) != null) {
                isOrphaned = false;
                break;
            }
        }

        return isOrphaned;
    }

    public static void preventInsertNoSourceDocument(List<Transaction__c> transactions) {

        for (Transaction__c tr : transactions) {

            Integer countOfSourceDocuments = 0;

            if (tr.Billing_Cash_Receipt__c != null) {
                countOfSourceDocuments++;
            }

            if (tr.Billing__c != null && !(tr.Billing_Cash_Receipt__c != null)) {
                countOfSourceDocuments++;
            }

            if (tr.Billing_Line__c != null && !(tr.Billing_Cash_Receipt__c != null)) {
                countOfSourceDocuments++;
            }

            if (tr.Cash_Disbursement__c != null) {
                countOfSourceDocuments++;
            }

            if (tr.Scheduled_Revenue_Expense__c != null) {
                countOfSourceDocuments++;
            }

            if (tr.Cash_Receipt__c != null) {
                countOfSourceDocuments++;
            }

            if (tr.Account_Payable__c != null && !(tr.AP_Disbursement__c != null)) {
                countOfSourceDocuments++;
            }

            if (tr.Account_Payable_Line__c != null && !(tr.AP_Disbursement__c != null)) {
                countOfSourceDocuments++;
            }

            if (tr.Journal_Entry_Line__c != null) {
                countOfSourceDocuments++;
            }

            if (tr.Time_Card_Day__c != null) {
                countOfSourceDocuments++;
            }

            if (tr.AP_Disbursement__c != null) {
                countOfSourceDocuments++;
            }

            if (ERP_ENABLED && isTransactionERPFieldsExist()) {
                for (SObjectField erpField : erpSourceDocumentFields) {
                    if (tr.get(erpField) != null) {
                        countOfSourceDocuments++;
                    }
                }
            }

            if (countOfSourceDocuments == 0 || countOfSourceDocuments > 1) {
                tr.addError(ONE_SOURCE_DOCUMENT_ERROR);
            }

        }
    }

    private static Boolean isTransactionERPFieldsExist() {
        if (isTransactionERPFieldsExist == NULL) {
            isTransactionERPFieldsExist = FALSE;
            Set<String> objectFields = Schema.SObjectType.Transaction__c.fields.getMap().keySet();
            if (objectFields.contains((ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c').toLowerCase())) {
                isTransactionERPFieldsExist = TRUE;
            }
        }

        return isTransactionERPFieldsExist;
    }

}