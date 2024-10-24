public without sharing class DomainUtils {

    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    private static String AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER = GlobalVariables.AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER;    

    public static List<SetupEntityAccess> getSetupEntityAccessRecords(Set<Id> entityIds, Set<Id> userIds) {
        List<SetupEntityAccess> result = [
            SELECT Id, SetupEntityId, SetupEntityType, ParentId
            FROM SetupEntityAccess
            WHERE SetupEntityId IN :entityIds
            AND ParentId IN (
                SELECT PermissionSetId
                FROM PermissionSetAssignment
                WHERE AssigneeId IN :userIds
            )
        ];
        return result;
    }

    public static Id getReportIdByDeveloperName(String reportDevName) {
        Id result;
        List<Report> reports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName = :reportDevName LIMIT 1
        ];
        if (!reports.isEmpty()) {
            result = reports[0].Id;
        }
        return result;
    }

    public static List<Report> getReportsByDeveloperNames(Set<String> reportDevNames) {
        return [SELECT Id, DeveloperName FROM Report WHERE DeveloperName IN :reportDevNames];
    }

    public static List<ContentDocumentLink> getContentDocumentLinksByLinkedEntityId(Set<Id> recordIds, Set<Id> documentIds) {
        String queryString =
            'SELECT Id, ContentDocumentId, LinkedEntityId ' +
            'FROM ContentDocumentLink ' +
            'WHERE LinkedEntityId IN :recordIds';

        if (documentIds != null && !documentIds.isEmpty()) {
            queryString += ' AND ContentDocumentId IN :documentIds';
        }
        return Database.query(queryString);
    }

    public static List<ContentDocumentLink> getContentDocumentLinksByLinkedEntityIdAndFileExt(
        Id linkedEntityId, Set<String> fileExtensions
    ) {

        return [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedEntityId
            AND ContentDocument.FileExtension IN :fileExtensions
        ];
    }

    public static List<ContentVersion> getFilesByLinkedEntityId(String linkedEntityId) {
        List<ContentVersion> result;
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink cdLink : [SELECT ContentDocumentId
                                            FROM ContentDocumentLink
                                            WHERE LinkedEntityId = :linkedEntityId LIMIT 50000]) {

            contentDocumentIds.add(cdLink.ContentDocumentId);
        }

        result = [
            SELECT Id, Title, FileType, FileExtension, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND ContentSize < :EmailFileSelectorController.FILE_SIZE_LIMIT
            ORDER BY Title LIMIT 50000
        ];

        return result;
    }

    public static List<ContentVersion> getFilesById(Set<Id> fileIds) {
        Set<String> stringSet = new Set<String>();
        for (Id fileId : fileIds) {
            stringSet.add(String.valueOf(fileId));
        }
        return getFilesById(stringSet);
    }

    public static List<ContentVersion> getFilesById(Set<String> fileIds) {
        List<ContentVersion> result = [
            SELECT Id, ContentDocumentId, VersionData, ContentSize
            FROM ContentVersion
            WHERE Id IN :fileIds
        ];
        return result;
    }

    public static List<ContentVersion> getFilesByContentDocumentId(Set<Id> contentDocumentIds) {
        List<ContentVersion> result = [
            SELECT Id, ContentDocumentId, Title, VersionData, ContentSize, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND ContentLocation = 'S'
            AND IsLatest = TRUE
            ORDER BY ContentModifiedDate DESC
        ];
        return result;
    }

    public static List<ContentDocument> getContentDocumentsById(Set<Id> contentDocumentIds) {
        List<ContentDocument> result = [
            SELECT Id
            FROM ContentDocument
            WHERE Id IN :contentDocumentIds
        ];
        return result;
    }

    public static List<AccountContactRole> getAccountContactRoleByAccountAndRole(Set<Id> accountIds, Set<String> roles) {
        List<AccountContactRole> result = [
            SELECT Id, IsPrimary, Role, ContactId, Contact.Email, AccountId
            FROM AccountContactRole
            WHERE AccountId IN : accountIds
            AND Role IN :roles
            AND Contact.Email != NULL
        ];

        return result;
    }

    public static List<SObject> getAccountContactRelationByAccountAndRole(Set<Id> accountIds, Set<String> roles) {
        List<String> quotedRoles = new List<String>();

        for (String role : roles) {
            quotedRoles.add('\'' + String.escapeSingleQuotes(role) + '\'');
        }

        String query = 'SELECT Id, IsActive, Roles, ContactId, Contact.Email, AccountId '
                + 'FROM AccountContactRelation '
                + 'WHERE AccountId IN :accountIds AND Roles includes (' + String.join(quotedRoles, ',') + ') AND Contact.Email != NULL';

        List<SObject> results = Database.query(query);
        return results;
    }

    public static Pricebook2 getStandardPricebook() {
        return [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
    }

    public static External_Settings__mdt getExternalSettingsByName(String devName) {
        External_Settings__mdt settings;
        try {
            settings = [
                SELECT Value_1__c, Value_2__c, Value_3__c, Value_4__c
                FROM External_Settings__mdt
                WHERE DeveloperName = :devName LIMIT 1
            ];
        }
        catch (Exception ex) {
            throw ex;
        }

        return settings;
    }

    public static List<Binding__mdt> getBindingsByType(String bindingType) {
        return [
            SELECT Label, DeveloperName, Namespace__c, Type__c, To__c, Is_Active__c
            FROM Binding__mdt
            WHERE Type__c = :bindingType
            AND Is_Active__c = TRUE
        ];
    }

    public static List<BDC_Binding__c> getAllBDCBindings() {
        return [
            SELECT Name, Type__c, To__c, Is_Active__c, Description__c
            FROM BDC_Binding__c
        ];
    }

    public static List<Accounting_Settings__c> getAccountingSettings() {
        String objectAPIName = Accounting_Settings__c.getSObjectType().getDescribe().Name;
        Map<String, Schema.SObjectField> fieldsAPINames = Accounting_Settings__c.getSObjectType().getDescribe().fields.getMap();

        String dynamicQueryString = 'SELECT';
        for (String fieldAPIName : fieldsAPINames.keySet()) {
            if (fieldsAPINames.get(fieldAPIName).getDescribe().isCustom()) {
                dynamicQueryString += ' ' + fieldAPIName + ',';
            }
        }

        //Strip off the last comma
        dynamicQueryString = dynamicQueryString.removeEnd(',');
        dynamicQueryString += ' FROM ' + objectAPIName + ' ORDER BY CreatedDate DESC LIMIT 1';
        return (List<Accounting_Settings__c>) Database.query(dynamicQueryString);
    }

    public static List<Account_Payable__c> getAccountPayablesById(Set<Id> ids){

        List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Ledger__c',
                'Ledger_Amount__c',
                'Accounting_Period__c',
                'Type__c',
                'Vendor__c',
                'Vendor__r.Default_Expense_GL_Account__c',
                'Vendor__r.GL_Account_Variable_1__c',
                'Vendor__r.GL_Account_Variable_2__c',
                'Vendor__r.GL_Account_Variable_3__c',
                'Vendor__r.GL_Account_Variable_4__c',
                'LastModifiedDate',
                'Balance_Minus_Discount__c',
                'Total__c',
                'Sub_Total__c',
                'Balance__c',
                'Date__c',
                'Payee__c',
                'Payee_Reference__c',
                'Currency_Conversion_Rate__c',
                'Status__c',
                'EarlyPayDate__c',
                'Vendor__r.Default_Expense_GL_Account__r.Name',
                'Vendor__r.Discount_Days_Due__c',
                'Vendor__r.Discount_Percent__c',
                'Discount_Amount__c',
                'On_Hold__c'
        };

        String queryCondition = 'Id IN :ids';

        String subQueryRelationshipName = GlobalVariables.PACKAGE_QUALIFIER + 'Project_Account_Payable_Lines__r';

        List<String> subQueryFields = new List<String>{'Id','Name'};

        if (MultiCurrencyHandler.isMultiCurrencyEnabled){
            queryFields.add('CurrencyIsoCode');
        }

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .subselectQuery(subQueryRelationshipName, false)
                .selectFields(subQueryFields)
                .setLimit(1);

        return (List<Account_Payable__c>)Database.query(theQuery.toSOQL());
    }

    public static List<Recurring_Account_Payable__c> getRecurringAccountPayablesById(Set<Id> ids) {
        List<Recurring_Account_Payable__c> result = [
            SELECT  Id,
                    Name,
                    Ledger__c,
                    Vendor__c,
                    Vendor__r.Default_Expense_GL_Account__c
            FROM Recurring_Account_Payable__c
            WHERE Id IN :ids
        ];

        return result;

    }

    public static List<Recurring_Billing__c> getRecurringBillingById(Set<Id> ids) {
        return [
            SELECT  Id,
                Name,
                Ledger__c,
                Customer__c
            FROM Recurring_Billing__c
            WHERE Id IN :ids
        ];
    }

    public static List<AggregateResult> getAccountPayablesByPayeeAndPayeeReferenceCount(Set<Id> vendorIds, Set<Id> contactIds, Set<Id> employeeIds, Set<String> payeeRefs) {
        String queryString = 
            'SELECT COUNT(Id) recCount, Payee_Reference__c payRef ' +
            (!vendorIds.isEmpty() ? ', Vendor__c vendor ' : ' ') +
            (!contactIds.isEmpty() ? ', Contact__c contact ' : ' ') +
            (!employeeIds.isEmpty() ? ', Employee__c employee ' : ' ') +
            'FROM Account_Payable__c ' +
            'WHERE (' +
            (!vendorIds.isEmpty() ? 'Vendor__c IN :vendorIds' : '') +
            (!vendorIds.isEmpty() && !contactIds.isEmpty() ? ' OR ' : '') +
            (!contactIds.isEmpty() ? 'Contact__c IN :contactIds' : '') +
            ((!vendorIds.isEmpty() || !contactIds.isEmpty()) && !employeeIds.isEmpty() ? ' OR ' : '') +
            (!employeeIds.isEmpty() ? 'Employee__c IN :employeeIds' : '') +
            ') AND Payee_Reference__c IN :payeeRefs ' +
            'GROUP BY Payee_Reference__c ' +
            (!vendorIds.isEmpty() ? ', Vendor__c ' : ' ') +
            (!contactIds.isEmpty() ? ', Contact__c ' : ' ') +
            (!employeeIds.isEmpty() ? ', Employee__c ' : ' ') +
            'HAVING COUNT(Id) > 1';
        return new List<AggregateResult>((AggregateResult[])Database.query(queryString));
    }

    public static List<Account_Payable__c> getAccountPayablesByIdForUpdate(Set<Id> ids) {
        List<Account_Payable__c> result = [
            SELECT Id, Name, Status__c, Accounting_Period__c, LastModifiedDate
            FROM Account_Payable__c
            WHERE Id IN :ids FOR UPDATE 
        ];

        return result;
    }

    public static Database.QueryLocator getQueryLocatorForCxSettlementBatch(Set<Id> ids,Set<String> batchIds) {
        String q = 
            'SELECT ' +
                'Id, ' +
                'Name, ' +
                'Ledger__c, ' +
                'Deposit_Date__c, ' +
                'Merchant_Batch_Id__c, ' +
                'CreatedDate, ' +
                'Ledger_Amount__c, ' +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'CurrencyIsoCode, ' : '') +
                '(' +
                    'SELECT ' +
                        'Id, ' +
                        'Payment_Processor__c, ' +
                        'Payment_Processor__r.Merchant_GL_Account__c, ' +
                        'Payment_Processor__r.Bank_GL_Account__c, ' +
                        'Payment_Processor__r.Merchant_Fees_GL_Account__c, ' +
                        'Payment_Processor__r.Convenience_Fees_GL_Account__c, ' +
                        'Payment_Processor__r.Last_Sync__c ' +
                    'FROM Cash_Receipts__r LIMIT 1' +
                ') ' +
            'FROM Bank_Deposit__c ' +  
            'WHERE Id IN :ids AND Merchant_Batch_Id__c NOT IN :batchIds';
        return Database.getQueryLocator(q);
    }

    public static List<AggregateResult> getPaymentProcessingFeesByBankDeposit(Set<Id> bankDepositIds) {
        return [
            SELECT SUM(Fee_Number__c) feeSum,SUM(Cash_Receipt__r.Convenience_Fees_Ledger_Amount__c) convenienceFee, Cash_Receipt__r.Bank_Deposit__c bankDep 
            FROM Payment_Activity__c 
            WHERE Cash_Receipt__r.Bank_Deposit__c IN :bankDepositIds 
            GROUP BY Cash_Receipt__r.Bank_Deposit__c
        ];
    }

    public static Set<Id> getExpenseLineIdsByAccountPayableLineIds(Set<Id> ids) {
        return new Map<Id,Expense_Line__c>([
                    SELECT Id
                    FROM Expense_Line__c
                    WHERE Account_Payable_Line__c IN :ids
                ]).keySet();
    }

    public static Map<Id,Account_Payable_Line__c> getAccountPayableLinesByMasterId(Set<Id> masterIds) {
        return new Map<Id,Account_Payable_Line__c>([
            SELECT Id,
                Account_Payable__c,
                Ledger__c,
                Product__c,
                Project__c,
                Project_Task__c,
                Expense_GL_Account__c,
                GL_Account_Variable_1__c,
                GL_Account_Variable_2__c,
                GL_Account_Variable_3__c,
                GL_Account_Variable_4__c,
                Sub_Total__c,
                Tax_Line__c,
                Tax_Group__c,
                Tax_Amount__c,
                Account_Payable__r.Total__c,
                Account_Payable__r.Currency_Conversion_Rate__c
            FROM Account_Payable_Line__c
            WHERE Account_Payable__c IN :masterIds
        ]);
    }

    public static List<AP_Disbursement__c> getApDisbursementsById(Set<Id> ids) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                    Name,
                    Paid_Amount__c,
                    Account_Payable__r.Status__c,
                    Account_Payable__r.Accounting_Period__c,
                    Account_Payable__r.Accounting_Period__r.Status__c,
                    Account_Payable__r.Ledger__c,
                    Cash_Disbursement__c,
                    Cash_Disbursement__r.Accounting_Period__c,
                    Cash_Disbursement__r.Status__c,
                    Cash_Disbursement__r.Debit_GL_Account__c,
                    Cash_Disbursement__r.Ledger__c,
                    Accounting_Period__r.Status__c,
                    (SELECT Id FROM Transactions__r LIMIT 1)
            FROM AP_Disbursement__c
            WHERE Id IN :ids
        ];

        return result;
    }

    public static List<AP_Disbursement__c> getApDisbursementsByIdOrderByPeriod(Set<Id> ids) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                Name,
                CreatedDate,
                Paid_Amount__c,
                Discount_Amount__c,
                Account_Payable__r.Status__c,
                Account_Payable__r.Ledger__c,
                Account_Payable__r.Accounting_Period__c,
                Account_Payable__r.Accounting_Period__r.Status__c,
                Cash_Disbursement__c,
                Cash_Disbursement__r.Accounting_Period__c,
                Cash_Disbursement__r.Status__c,
                Cash_Disbursement__r.Debit_GL_Account__c,
                Cash_Disbursement__r.Ledger__c,
                Cash_Disbursement__r.Currency_Conversion_Rate__c,
                Accounting_Period__r.Status__c
            FROM AP_Disbursement__c
            WHERE Id IN :ids
            ORDER BY CreatedDate ASC
        ];

        return result;
    }

    public static List<AP_Disbursement__c> getApDisbursementsByIdForUpdate(Set<Id> ids) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                    Status__c
            FROM AP_Disbursement__c
            WHERE Id IN :ids
            FOR UPDATE
        ];

        return result;
    }

    public static List<AP_Disbursement__c> getApDisbursementsByDisbursement(Set<Id> disbursementIds) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                    Name,
                    Account_Payable__c,
                    Account_Payable__r.Payment_Status__c,
                    Account_Payable__r.Paid_Amount__c,
                    Cash_Disbursement__c,
                    Cash_Disbursement__r.Status__c,
                    Cash_Disbursement__r.Accounting_Period__c,
                    Cash_Disbursement__r.Payment_Status__c,
                    Cash_Disbursement__r.Cash_Disbursement_Batch__c,
                    Cash_Disbursement__r.Source__c,
                    Accounting_Period__c
            FROM AP_Disbursement__c
            WHERE Cash_Disbursement__c IN :disbursementIds
        ];
        return result;
    }

    public static List<AP_Disbursement__c> getApDisbursementsByDisbursementBatch(Set<Id> disbursementBatchIds) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                    Name,
                    Account_Payable__c,
                    Account_Payable__r.Payment_Status__c,
                    Account_Payable__r.Paid_Amount__c,
                    Cash_Disbursement__c,
                    Cash_Disbursement__r.Status__c,
                    Cash_Disbursement__r.Payment_Status__c,
                    Cash_Disbursement__r.Cash_Disbursement_Batch__c
            FROM AP_Disbursement__c
            WHERE Cash_Disbursement__r.Cash_Disbursement_Batch__c IN :disbursementBatchIds
        ];
        return result;
    }
    
    public static List<AP_Disbursement__c> getAPDisbursementByRelatedPayableIdAndCDStatus(Set<Id> ids, String periodName) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                    Account_Payable__c,
                    Accounting_Period__c,
                    Accounting_Period__r.Name,
                    Cash_Disbursement__r.Accounting_Period__r.Name,
                    Cash_Disbursement__r.Payment_Status__c,
                    Cash_Disbursement__r.Debit_GL_Account__c,
                    Cash_Disbursement__r.Ledger__c,
                    Paid_Amount__c,
                    Discount_Amount__c,
                    Account_Payable__r.Total__c,
                    Net_Amount__c
            FROM AP_Disbursement__c
            WHERE Account_Payable__c IN :ids
            AND Accounting_Period__r.Name <= :periodName
            ORDER BY Accounting_Period__r.Name ASC
        ];
        return result;
    }

    public static List<AP_Disbursement__c> getAPDisbursementByPayableId(Set<Id> ids) {
        List<AP_Disbursement__c> result = [
            SELECT  Id,
                Account_Payable__c,
                Accounting_Period__c,
                Accounting_Period__r.Name,
                Cash_Disbursement__r.Accounting_Period__r.Name,
                Cash_Disbursement__r.Payment_Status__c,
                Cash_Disbursement__r.Debit_GL_Account__c,
                Cash_Disbursement__r.Ledger__c,
                Account_Payable__r.Ledger__c,
                Paid_Amount__c,
                Discount_Amount__c,
                Account_Payable__r.Total__c,
                Net_Amount__c,
                Status__c,
                (SELECT Id,
                    AP_Disbursement__c,
                    Account_Payable_Line__c,
                    Transaction_Key__c,
                    Amount__c,
                    Foreign_Amount__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    GL_Account__c,
                    Time_Card_Variable_1__c,
                    Time_Card_Variable_2__c,
                    Project__c,
                    Project_Task__c,
                    Product__c,
                    Ledger__c
                FROM Transactions__r)
            FROM AP_Disbursement__c
            WHERE Account_Payable__c IN :ids
        ];
        return result;
    }

    public static List<AggregateResult> getApDisbursementsByCashDisbursementCount(Set<Id> ids) {
        return [SELECT COUNT(Id), Cash_Disbursement__c
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c IN :ids
                GROUP BY Cash_Disbursement__c];
    }

    public static Map<Id,Cash_Disbursement_Batch__c> getCashDisbursementBatchMapById(Set<Id> ids, Boolean isMultiCurrencyEnabled) {
        List<String> queryFields = new List<String>{
            'Id'
        };

        if (isMultiCurrencyEnabled == true) {
            queryFields.add('CurrencyIsoCode');
        }

        return new Map<Id, Cash_Disbursement_Batch__c>(
            (List<Cash_Disbursement_Batch__c>) Database.query(
                'SELECT ' + String.join(queryFields, ',') + ' FROM Cash_Disbursement_Batch__c WHERE Id IN :ids'
            )
        );
    }

    public static List<Cash_Disbursement_Batch__c> getCashDisbursementBatchById(Set<Id> ids, Boolean isMultiCurrencyEnabled) {
        List<String> queryFields = new List<String>{
            'Id'
        };
        if (isMultiCurrencyEnabled == true) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id IN :ids';

        List<String> subQueryFields = new List<String>{
            'Id'
        };

        String subQueryRelationshipName = GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement_Batch__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(subQueryFields)
            .setLimit(1);

        return (List<Cash_Disbursement_Batch__c>) Database.query(theQuery.toSOQL());
    }

    public static List<Cash_Disbursement_Batch__c> getCashDisbursementBatchWithPostedCDsById(Set<Id> ids) {
        List<Cash_Disbursement_Batch__c> result = [
            SELECT  Id,
                    (
                        SELECT Id
                        FROM Cash_Disbursements__r
                        WHERE Status__c = 'Posted' LIMIT 1
                    )
            FROM Cash_Disbursement_Batch__c
            WHERE Id IN :ids
        ];

        return result;
    }

    public static List<Cash_Disbursement_Batch__c> getCashDisbursementBatchWithMatchedCDsById(Set<Id> ids) {
        List<Cash_Disbursement_Batch__c> result = [
            SELECT
                Id,
                (
                    SELECT Id, Bank_Transaction__c
                    FROM Cash_Disbursements__r
                    WHERE Bank_Transaction__c != NULL
                )
            FROM Cash_Disbursement_Batch__c
            WHERE Id IN :ids
        ];

        return result;
    }

    public static Integer getCountOfCashDisbursementsByCDB(Id cdbId, String postingStatus) {
        Integer result = [
            SELECT COUNT()
            FROM Cash_Disbursement__c
            WHERE Cash_Disbursement_Batch__c = :cdbId
            AND Status__c = :postingStatus
        ];
        return result;
    }

    public static List<Cash_Disbursement__c> getCashDisbursementsByCDB(Id cdbId) {
        List<Cash_Disbursement__c> result = [
            SELECT Id
            FROM Cash_Disbursement__c
            WHERE Cash_Disbursement_Batch__c = :cdbId
        ];
        return result;
    }

    public static List<Cash_Disbursement__c> getCashDisbursementByIdForUpdate(Set<Id> ids) {
        List<Cash_Disbursement__c> result = [
            SELECT Id, Name, Status__c, LastModifiedDate, Accounting_Period__c
            FROM Cash_Disbursement__c
            WHERE Id IN :ids
            FOR UPDATE
        ];
        return result;
    }

    public static List<Cash_Disbursement__c> getCashDisbursementByIdWithAPDs(Set<Id> ids) {
        List<Cash_Disbursement__c> result = [
            SELECT Id, Name, Debit_GL_Account__c, Ledger__c,
                    (SELECT Id FROM Account_Payable_Cash_Disbursements__r LIMIT 1)
            FROM Cash_Disbursement__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Cash_Receipt__c> getCashReceiptByIdForUpdate(Set<Id> ids) {
        List<Cash_Receipt__c> result = [
            SELECT Id, Status__c, Name, LastModifiedDate
            FROM Cash_Receipt__c
            WHERE Id IN :ids
            FOR UPDATE
        ];
        return result;
    }

    public static List<Cash_Disbursement__c> getCashDisbursementById(Set<Id> ids) {
        List<Cash_Disbursement__c> result = [
            SELECT Id,
                Name,
                Vendor__c,
                Debit_GL_Account__c,
                Reference__c,
                Description__c,
                Disbursement_Date__c,
                Source__c
            FROM Cash_Disbursement__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Cash_Receipt__c> getCashReceiptById(Set<Id> ids) {
        List<Cash_Receipt__c> result = [
            SELECT Id, Name, Account__c, Description__c, Credit_GL_Account__c, Receipt_Date__c, Amount__c,Payment_Reference__c,Payment_Processor__c,Balance__c
            FROM Cash_Receipt__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Financial_Report_Result__c> getFinancialReportResultsById(Set<Id> ids) {
        List<Financial_Report_Result__c> result;
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'CreatedBy.Name', 'Run_Finished__c', 'Ledger__c' , 'Rounding__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (List<Financial_Report_Result__c>) Database.query(theQuery.toSOQL());
        return result;
    }

    public static List<Financial_Report_Result__c> getFinancialReportResultsByBatchIdAndType(
        Set<Id> ids,
        String reportType,
        SOQLBuilder.SortOrder sortOrder,
        Integer queryLimit
    ) {

        List<String> queryFields = new List<String>{
            'Name',
            'Id',
            'Batch_ID__c',
            'Financial_Report_Definition__r.Name',
            'Financial_Report_Definition__c',
            'Accounting_Period__c',
            'Run_Started__c',
            'Run_Finished__c',
            'End_Accounting_Period__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Budget_Ledger__c',
            'Ledger__c',
            'CreatedById'
        };

        String queryCondition = 'Batch_ID__c IN :ids AND Report_Type__c = :reportType';

        List<String> subQueryFields = new List<String>{
            'Id', 'Name'
        };
        String subQueryRelationshipName = 'Attachments';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Financial_Report_Result__c', 'Run_Started__c', sortOrder);

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering)
            .setLimit(queryLimit)
            .subselectQuery(subQueryRelationshipName, false)
            .selectFields(subQueryFields);

        return (List<Financial_Report_Result__c>) Database.query(theQuery.toSOQL());
    }

    public static List<Financial_Report_Result__c> queryFinancialReportResultsByReportType(
        String reportType,
        SOQLBuilder.SortOrder sortOrder,
        Integer queryLimit
    ) {

        List<String> queryFields = new List<String>{
            'Name',
            'Id',
            'Batch_ID__c',
            'Financial_Report_Definition__r.Name',
            'Financial_Report_Definition__c',
            'Accounting_Period__c',
            'Run_Started__c',
            'Run_Finished__c',
            'End_Accounting_Period__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Budget_Ledger__c',
            'Ledger__c',
            'CreatedById'
        };

        String queryCondition = 'Report_Type__c = :reportType';

        List<String> subQueryFields = new List<String>{
            'Id', 'Name'
        };
        String subQueryRelationshipName = 'Attachments';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Financial_Report_Result__c', 'Run_Started__c', sortOrder);

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Result__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering)
            .setLimit(queryLimit)
            .subselectQuery(subQueryRelationshipName, false)
            .selectFields(subQueryFields);

        return (List<Financial_Report_Result__c>) Database.query(theQuery.toSOQL());
    }

    public static List<Financial_Report_Definition__c> getFinancialReportDefinitionByName(Set<String> names) {
        List<Financial_Report_Definition__c> result = [
            SELECT Id, Percentage_Decimal_Places__c
            FROM Financial_Report_Definition__c
            WHERE Name IN :names
        ];
        return result;
    }

    public static List<Financial_Report_Definition__c> getFinancialReportDefinitionWithRows(Id reportDefId) {
        return [
            SELECT Id,
            (SELECT AcctSeed__GL_Account__c FROM AcctSeed__Financial_Report_Rows__r
                WHERE AcctSeed__Type__c = 'GL Account'
                AND AcctSeed__GL_Account__r.AcctSeed__Type__c != 'Revenue'
                AND AcctSeed__GL_Account__r.AcctSeed__Type__c != 'Expense')
            FROM AcctSeed__Financial_Report_Definition__c WHERE Id = :reportDefId
        ];
    }

    public static List<Financial_Report_Row__c> getFinancialReportRowsByGLAccountId(Set<Id> glAccountIds) {
        List<Financial_Report_Row__c> result = [
            SELECT Id, GL_Account__c
            FROM Financial_Report_Row__c
            WHERE GL_Account__c IN :glAccountIds
        ];
        return result;
    }

    public static List<Fixed_Asset__c> getFixedAssetsById(Set<Id> ids) {
        List<Fixed_Asset__c> result = [
                SELECT  Id,
                        Name,
                        Ledger__c,
                        Value__c
                FROM Fixed_Asset__c
                WHERE Id IN :ids
        ];
        return result;
    }

    public static List<AP_Credit_Memo__c> getApCreditMemosByMasterRecordId(Set<Id> masterRecordIds, String periodName) {
        List<AP_Credit_Memo__c> result = [
            SELECT Id,
                    Amount__c,
                    Accounting_Period__r.Name,
                    Account_Payable_Credit_Memo__c,
                    Account_Payable_Invoice__c,
                    Account_Payable_Credit_Memo__r.Total__c,
                    Account_Payable_Invoice__r.Total__c
            FROM AP_Credit_Memo__c
            WHERE (Account_Payable_Credit_Memo__c IN :masterRecordIds
            OR Account_Payable_Invoice__c IN :masterRecordIds)
            AND Accounting_Period__r.Name <= :periodName
        ];

        return result;
    }

    public static List<AP_Credit_Memo__c> getApCreditMemosByInvoiceId(Set<Id> masterRecordIds) {
        List<AP_Credit_Memo__c> result = [
            SELECT Id,
                Amount__c,
                Accounting_Period__c,
                Accounting_Period__r.Name,
                Account_Payable_Credit_Memo__c,
                Account_Payable_Invoice__c,
                Account_Payable_Credit_Memo__r.Total__c,
                Account_Payable_Invoice__r.Total__c
            FROM AP_Credit_Memo__c
            WHERE Account_Payable_Invoice__c IN :masterRecordIds
            ORDER BY CreatedDate DESC
        ];

        return result;
    }

    public static Map<Id, AggregateResult> getAPCreditMemoSumByPayable(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT Account_Payable_Credit_Memo__c Id, SUM(Amount_Number__c) SUM
            FROM AP_Credit_Memo__c
            WHERE Account_Payable_Credit_Memo__c IN :ids
            GROUP BY Account_Payable_Credit_Memo__c]);
    }

    public static Map<Id, AggregateResult> getAPInvoiceSumByPayable(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT Account_Payable_Invoice__c Id, SUM(Amount_Number__c) SUM
            FROM AP_Credit_Memo__c
            WHERE Account_Payable_Invoice__c IN :ids
            GROUP BY Account_Payable_Invoice__c]);
    }

    public static Map<Id, AggregateResult> getAPCreditMemoMaxPeriodByPayable(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
        [SELECT Account_Payable_Credit_Memo__c Id, MAX(Accounting_Period__r.Name) MAX
        FROM AP_Credit_Memo__c
        WHERE Account_Payable_Credit_Memo__c IN :ids
        GROUP BY Account_Payable_Credit_Memo__c]);
    }

    public static Map<Id, AggregateResult> getAPInvoiceMaxPeriodByPayable(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
        [SELECT Account_Payable_Invoice__c Id, MAX(Accounting_Period__r.Name) MAX
        FROM AP_Credit_Memo__c
        WHERE Account_Payable_Invoice__c IN :ids
        GROUP BY Account_Payable_Invoice__c]);
    }

    public static Map<Id, AggregateResult> getApDisbursementsMaxPeriodByAP(Set<Id> ids) {
        return new Map<Id, AggregateResult> (
        [SELECT Account_Payable__c Id, MAX(Accounting_Period__r.Name) MAX
        FROM AP_Disbursement__c
        WHERE Account_Payable__c IN :ids
        GROUP BY Account_Payable__c]);
    }

    public static Integer getCountCurrentAndRetainedEarnings(Set<Id> currentPeriodIds, Set<Id> nextPeriodIds) {
        Integer result = [
            SELECT COUNT()
            FROM Financial_Cube__c
            WHERE (
                (Accounting_Period__c IN :currentPeriodIds AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS)
                OR
                (Accounting_Period__c IN :nextPeriodIds AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS)
            )
            AND (Ledger_Type__c = :LedgerActions.LEDGER_TYPE_TRANSACTIONAL OR Ledger_Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL)
        ];
        return result;
    }

    public static List<Financial_Cube__c> getFinancialCubesById(Set<Id> ids) {
        List<Financial_Cube__c> result = [
            SELECT  Id,
                    Ledger_Type__c,
                    Cube_Type__c,
                    Accounting_Period__r.Status__c,
                    Opening_Balance__c,
                    Accounting_Period_Status__c,
                    (SELECT Id FROM Financial_Cube_Transactions__r LIMIT 1)
            FROM Financial_Cube__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Financial_Cube__c> getFinancialCubes(Set<Id> ids) {
        List<Financial_Cube__c> result = [
            SELECT Id
            FROM Financial_Cube__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Financial_Cube__c> getFinancialCubesForReporting(Set<Id> periodIds, Set<Id> glAccountIds, Set<Id> ledgerIds) {
        List<Financial_Cube__c> result = [
            SELECT  Id,
                    Name,
                    GL_Account__c,
                    Opening_Balance__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Key__c,
                    Cube_Type__c,
                    Year__c,
                    Ledger__c,
                    Current_Period__c,
                    Accounting_Period__c,
                    Accounting_Period__r.Name,
                    Year_To_Date__c,
                    Transaction_Amount__c,
                    Amount__c,
                    GL_Account__r.Name
            FROM Financial_Cube__c
            WHERE (Current_Period__c != 0 OR Opening_Balance__c != 0 OR Transaction_Amount__c != 0)
            AND Accounting_Period__c IN :periodIds
            AND GL_Account__c IN :glAccountIds
            AND Ledger__c IN :ledgerIds
            LIMIT 50000
        ];

        return result;
    }

    public static Database.QueryLocator getQueryLocatorForCubesDeletion(Set<String> types, Set<Id> accountingPeriodIds) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Financial_Cube__c
            WHERE (Cube_Type__c IN :types OR IsTranslatedCube__c = TRUE)
            AND Accounting_Period__c IN :accountingPeriodIds
        ]);
    }

    public static List<Financial_Cube__c> getTranslatedCubesBySourceCubeIds(Set<Id> sourceCubeIds) {
        return [
            SELECT Id
            FROM Financial_Cube__c
            WHERE Source_Cube__c =: sourceCubeIds AND IsTranslatedCube__c = TRUE
        ];
    }

    public static List<Financial_Cube__c> getFinancialCubesByLedgerByTypeByPeriodByGroupKeys( Set<String> ledgerTypes,
                                                                                              Set<String> cubeTypes,
                                                                                              Id periodId,
                                                                                              Set<String> groupKeys ) {

        List<Financial_Cube__c> result = [
            SELECT  Id,
                    Accounting_Period__c,
                    GL_Account__c,
                    GL_Account__r.Type__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Opening_Balance__c,
                    Amount__c,
                    Cube_Type__c,
                    Current_Period__c,
                    Key_Group__c,
                    Transaction_Amount__c,
                    Ledger__c
            FROM Financial_Cube__c
            WHERE Ledger_Type__c IN :ledgerTypes
            AND Cube_Type__c IN :cubeTypes
            AND Accounting_Period__c = :periodId
            AND Key_Group__c IN :groupKeys
        ];

        return result;
    }

    public static Integer getCountFinancialCubesByPeriodAndGLAccountAndLedger(Set<Id> periodIds, Set<Id> glAccountIds, Set<Id> ledgerIds) {
        Integer result = [
            SELECT  COUNT()
            FROM Financial_Cube__c
            WHERE (Current_Period__c != 0 OR Opening_Balance__c != 0 OR Transaction_Amount__c != 0)
            AND Accounting_Period__c IN :periodIds
            AND GL_Account__c IN :glAccountIds
            AND Ledger__c IN :ledgerIds
        ];

        return result;
    }

    public static Integer getCountFinancialCubesByPeriodAndTypeAndLedger(Set<Id> periodIds, Set<String> types, Set<Id> ledgerIds) {
        Integer result = [
            SELECT  COUNT()
            FROM Financial_Cube__c
            WHERE Cube_Type__c IN :types
            AND Accounting_Period__c IN :periodIds
            AND Ledger__c IN :ledgerIds
        ];

        return result;
    }

    public static List<AggregateResult> getYTDBalanceForFinancialCubesByPeriodAndGLAccountAndLedger(Set<Id> periodIds, Set<Id> glAccountIds, Set<Id> ledgerIds) {
        List<AggregateResult> results = [
            SELECT SUM(Year_To_Date__c) balance
            FROM Financial_Cube__c
            WHERE (Current_Period__c != 0 OR Opening_Balance__c != 0 OR Transaction_Amount__c != 0)
            AND Accounting_Period__c IN :periodIds
            AND GL_Account__c IN :glAccountIds
            AND Ledger__c IN :ledgerIds
        ];

        return results;
    }

    public static List<AggregateResult> getPeriodBalanceForFinancialCubesByPeriodAndGLAccountAndLedger(Set<Id> periodIds, Set<Id> glAccountIds, Set<Id> ledgerIds) {
        List<AggregateResult> results = [
            SELECT SUM(Current_Period__c) balance
            FROM Financial_Cube__c
            WHERE (Current_Period__c != 0 OR Opening_Balance__c != 0 OR Transaction_Amount__c != 0)
            AND Accounting_Period__c IN :periodIds
            AND GL_Account__c IN :glAccountIds
            AND Ledger__c IN :ledgerIds
        ];

        return results;
    }

    public static List<Financial_Cube__c> getFinancialCubesByKeyByLedgerIdByCubeType(
        Set<String> keySet, Set<Id> ledgerIds, Set<String> cubeTypes) {
        List<Financial_Cube__c> result = [
            SELECT  Id,
                    Name,
                    GL_Account__c,
                    Accounting_Period__c,
                    Amount__c,
                    Year__c,
                    Cube_Type__c,
                    Ledger__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c
            FROM Financial_Cube__c
            WHERE Key__c IN :keySet
            AND Cube_Type__c IN :cubeTypes
            AND Ledger__c IN :ledgerIds
        ];
        return result;
    }

    public static List<Financial_Cube__c> getFinancialCubesByGLAccount(Set<Id> glAccountIds) {
        List<Financial_Cube__c> result = [
            SELECT Id, GL_Account__c FROM Financial_Cube__c WHERE Gl_Account__c IN :glAccountIds
        ];
        return result;
    }

    public static List<Financial_Cube_Transaction__c> getFinancialCubeTransactionsByTransaction(List<Transaction__c> transactions) {
        List<Financial_Cube_Transaction__c> result = [
            SELECT Id, Financial_Cube__c, Financial_Cube__r.Cube_Type__c, Financial_Cube__r.Ledger__c, Transaction__c
            FROM Financial_Cube_Transaction__c
            WHERE Transaction__c IN :transactions
        ];
        return result;
    }

    public static AggregateResult[] getFinancialCubeTransactionsByFinCubesAggregateResults(List<Financial_Cube__c> finCubes) {
        AggregateResult[] groupedResults = [
            SELECT COUNT(Id), Financial_Cube__c
            FROM Financial_Cube_Transaction__c
            WHERE Financial_Cube__c IN :finCubes
            GROUP BY Financial_Cube__c
        ];
        return groupedResults;
    }

    public static List<Financial_Cube__c> getOriginalConsolidationFinancialCubesByKeys(Set<String> keys) {
        List<Financial_Cube__c> result = [
            SELECT Id, Opening_Balance__c, Amount__c, Key__c
            FROM Financial_Cube__c
            WHERE Key__c IN :keys
            AND IsTranslatedCube__c = FALSE
        ];
        return result;
    }

    public static List<Financial_Cube__c> getTranslatedFinancialCubesByKey(Set<String> keySet) {
        List<Financial_Cube__c> result = [
            SELECT  Id
            FROM Financial_Cube__c
            WHERE Key__c IN :keySet
            AND IsTranslatedCube__c = TRUE
        ];
        return result;
    }

    public static List<Financial_Cube__c> getFinancialCubesByGLAccountAndLedgerAndPeriod(Set<Id> glAccountIds, Set<Id> ledgerIds, Set<Id> periodIds) {
        List<Financial_Cube__c> result = [
            SELECT Id
            FROM Financial_Cube__c
            WHERE Accounting_Period__c IN :periodIds
            AND Ledger__c IN :ledgerIds
            AND Gl_Account__c IN :glAccountIds
            AND IsTranslatedCube__c = TRUE
        ];
        return result;
    }


    public static List<SObject> query(String q,Set<Id> headerIds) {
        return Database.query(q);
    }
    public static Database.QueryLocator getQueryLocator(Set<Id> headerIds,String query) {
        return Database.getQueryLocator(query);
    }
    public static Database.QueryLocator getQueryLocator(String query) {
        return Database.getQueryLocator(query);
    }

    public static Database.QueryLocator getQueryLocator(String query, Set<Id> genericIdSet) {
        return Database.getQueryLocator(query);
    }

    public static Database.QueryLocator getQueryLocator(String query, Set<String> genericStringSet) {
        return Database.getQueryLocator(query);
    }

    public static Database.QueryLocator getQueryLocator(String query, Date today) {
        return Database.getQueryLocator(query);
    }
    
    public static List<SObject> query(String query, System.AccessLevel accessLevel) {
        return Database.query(query, accessLevel);
    } 
    
    public static List<SObject> queryWithBinds(String query, Map<String,Object> bindMap, System.AccessLevel accessLevel) {
        return Database.queryWithBinds(query, bindMap, accessLevel);
    }

    public static Database.QueryLocator getQueryLocator(String query, System.AccessLevel accessLevel) {
        return Database.getQueryLocator(query, accessLevel);
    }

    public static Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String,Object> bindMap, System.AccessLevel accessLevel) {
        return Database.getQueryLocatorWithBinds(query, bindMap, accessLevel);
    }

    public static Database.QueryLocator getQueryLocatorForFinancialReportBatch(
        String query, Set<Id> accountingPeriodIds, Set<Id> glAccountIds, Set<Id> ledgerIds
    ) {

        return Database.getQueryLocator(query);
    }

    public static Database.QueryLocator getQueryLocatorForConsolidationRoutineBatch(String query, Id accountingPeriodId, Set<Id> consolidatedLedgers) {
        return Database.getQueryLocator(query);
    }

    public static Database.QueryLocator getQueryLocatorForFCTranslationBatch(String query, Id accountingPeriodId, Set<Id> ledgerIds) {
        return Database.getQueryLocator(query);
    }

    public static Database.QueryLocator getQueryLocatorForArchiveDeleteFCubesBatch(Accounting_Period__c acctPeriod) {
        return Database.getQueryLocator([
            SELECT Id, Transaction_Amount__c
            FROM Financial_Cube__c
            WHERE Accounting_Period__c = :acctPeriod.Id
            AND Cube_Type__c IN (:FinancialCubeActions.FINANCIAL_CUBE_PERIOD, :FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW)
            AND (Opening_Balance__c = 0 OR Opening_Balance__c = NULL)
        ]);
    }

    public static Database.QueryLocator getQueryLocatorForDeleteCurrentAndRetainedEarningsBatch(Set<Id> currentPeriodIds, Set<Id> nextPeriodIds) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Financial_Cube__c
            WHERE (Ledger_Type__c = :LedgerActions.LEDGER_TYPE_TRANSACTIONAL OR Ledger_Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL)
            AND (
                (Accounting_Period__c IN :currentPeriodIds AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS)
                OR
                (Accounting_Period__c IN :nextPeriodIds AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS)
            )
        ]);
    }

    public static Database.QueryLocator getQueryLocatorForPurgeZeroBalanceFinancialCubesBatch() {
        Set<String> fCubeTypes = new Set<String>{
            FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
            FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW,
            FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
        };
        Set<String> ledgerTypes = new Set<String>{
            LedgerActions.LEDGER_TYPE_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
        };
        Set<String> periodStatuses = new Set<String>{
            AccountingPeriodActions.OPEN_STATUS,
            AccountingPeriodActions.CLOSED_STATUS
        };

        String query =
            'SELECT  ' +
                'Id, ' +
                '(SELECT Id FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube_Transactions__r LIMIT 1) ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
            'WHERE ' + PACKAGE_QUALIFIER + 'Cube_Type__c IN :fCubeTypes ' +
            'AND ' + PACKAGE_QUALIFIER + 'Ledger_Type__c IN :ledgerTypes ' +
            'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period_Status__c IN :periodStatuses ' +
            'AND ' + PACKAGE_QUALIFIER + 'Opening_Balance__c = 0 ' +
            'AND ' + PACKAGE_QUALIFIER + 'Current_Period__c = 0';

        return Database.getQueryLocator(query);
    }

    public static List<Billing_Format__c> getBillingFormatsById(Set<Id> ids) {
        List<Billing_Format__c> result = [
            SELECT Id, Type__c, Default_Email_Template__c, Visualforce_PDF_Page__c, ReplyTo_Email__c, Org_Wide_Email_Address__c
            FROM Billing_Format__c
            WHERE Id IN : ids
        ];
        return result;
    }
    
    public static List<GL_Account__c> getGlAccountsForBalanceSheetReport(Boolean isGroupBySubtype1) {
        List<String> validSubTypes1 = new List<String>{'Assets', 'Liabilities', 'Owners Equity'};

        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Type__c', 'Sub_Type_1__c', 'Sub_Type_2__c'
        };

        String queryCondition =
            'Type__c = \'Balance Sheet\' ' +
            'AND Sub_Type_1__c IN :validSubTypes1 ' +
            'ORDER BY Sub_Type_1__c ASC ' +
            (isGroupBySubtype1 ? ', Sub_Type_2__c ASC' : '') + ', Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }

    public static List<GL_Account__c> getGlAccountsForBalanceSheetReportId(Boolean isGroupBySubtype1, Set<Id> glAccountIds) {
        List<String> validSubTypes1 = new List<String>{'Assets', 'Liabilities', 'Owners Equity'};

        List<String> queryFields = new List<String>{
                'Id', 'Name', 'Type__c', 'Sub_Type_1__c', 'Sub_Type_2__c'
        };

        String queryCondition =
                'Type__c = \'Balance Sheet\' ' +
                'AND Sub_Type_1__c IN :validSubTypes1 ' +
                'AND Id IN :glAccountIds ' +
                'ORDER BY Sub_Type_1__c ASC ' +
                (isGroupBySubtype1 ? ', Sub_Type_2__c ASC' : '') + ', Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }

    public static List<GL_Account__c> getGlAccountsForProfitAndLossReport(Boolean isGroupBySubtype1, Boolean isGroupBySubtype2) {
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Type__c', 'Sub_Type_1__c', 'Sub_Type_2__c'
        };

        String queryCondition =
            'Type__c IN (\'Revenue\', \'Expense\') ' +
            'ORDER By Type__c ASC ' +
            (isGroupBySubtype1 ? ', Sub_Type_1__c ASC' : '') +
            (isGroupBySubtype2 ? ', Sub_Type_2__c ASC' : '') +
                ', Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }

    public static List<GL_Account__c> getGlAccountsForProfitAndLossReportById(Boolean isGroupBySubtype1, Boolean isGroupBySubtype2, Set<Id> glAccountIds) {
        List<String> queryFields = new List<String>{
                'Id', 'Name', 'Type__c', 'Sub_Type_1__c', 'Sub_Type_2__c'
        };

        String queryCondition =
                'Type__c IN (\'Revenue\', \'Expense\') ' +
                'AND Id IN :glAccountIds ' +
                        'ORDER By Type__c ASC ' +
                        (isGroupBySubtype1 ? ', Sub_Type_1__c ASC' : '') +
                        (isGroupBySubtype2 ? ', Sub_Type_2__c ASC' : '') +
                        ', Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }

    public static List<AggregateResult> getNonZeroGlAccountsProfitAndLoss(FinancialReportOptions reportOptions) {
        List<Id> ledgerIds = reportOptions.getLedgerIds();
        List<String> periodList = reportOptions.getListOfPeriodNames();
        List<GL_Account__c> glAccounts = reportOptions.glAccounts;
        String glavVar1 = reportOptions.glVariable1;
        String glavVar2 = reportOptions.glVariable2;
        String glavVar3 = reportOptions.glVariable3;
        String glavVar4 = reportOptions.glVariable4;
        String currencyISO = reportOptions.currencyISO;

        String queryString =
            'SELECT COUNT(Id) finCubes, GL_Account__c glAccount '
            + 'FROM Financial_Cube__c '
            + 'WHERE Accounting_Period__r.Name IN :periodList '
            + (
                MultiCurrencyHandler.isMultiCurrencyEnabled
                    ? 'AND CurrencyIsoCode = \'' + String.escapeSingleQuotes(currencyISO) + '\' '
                    : ''
            )
            + 'AND Current_Period__c != 0 '
            + 'AND Ledger__c IN :ledgerIds '
            + 'AND GL_Account__c IN :glAccounts ';

        if (!String.isBlank(glavVar1)) {
            queryString += ' AND GL_Account_Variable_1__c = :glavVar1 ';
        }

        if (!String.isBlank(glavVar2)) {
            queryString += ' AND GL_Account_Variable_2__c = :glavVar2 ';
        }

        if (!String.isBlank(glavVar3)) {
            queryString += ' AND GL_Account_Variable_3__c = :glavVar3 ';
        }

        if (!String.isBlank(glavVar4)) {
            queryString += ' AND GL_Account_Variable_4__c = :glavVar4 ';
        }

        queryString += 'GROUP BY GL_Account__c '
                    + 'HAVING SUM(Current_Period__c) != 0 OR MAX(Current_Period__c) != 0 OR MIN(Current_Period__c) != 0';

        return Database.query(queryString);
    }

    public static List<AggregateResult> getNonZeroGlAccountsBalanceSheet(FinancialReportOptions reportOptions) {
        List<Id> ledgerIds = reportOptions.getLedgerIds();
        List<String> periodList = reportOptions.getListOfPeriodNames();
        List<GL_Account__c> glAccounts = reportOptions.glAccounts;
        String glavVar1 = reportOptions.glVariable1;
        String glavVar2 = reportOptions.glVariable2;
        String glavVar3 = reportOptions.glVariable3;
        String glavVar4 = reportOptions.glVariable4;
        String currencyISO = reportOptions.currencyISO;

        String queryString =
            'SELECT COUNT(Id) finCubes, GL_Account__c glAccount '
            + 'FROM Financial_Cube__c '
            + 'WHERE Accounting_Period__r.Name IN :periodList '
            + (
                MultiCurrencyHandler.isMultiCurrencyEnabled
                    ? 'AND CurrencyIsoCode = \'' + String.escapeSingleQuotes(currencyISO) + '\' '
                    : ''
            )
            + 'AND Year_To_Date__c != 0 '
            + 'AND Ledger__c IN :ledgerIds '
            + 'AND GL_Account__c IN :glAccounts ';

        if (!String.isBlank(glavVar1)) {
            queryString += ' AND GL_Account_Variable_1__c = :glavVar1 ';
        }

        if (!String.isBlank(glavVar2)) {
            queryString += ' AND GL_Account_Variable_2__c = :glavVar2 ';
        }

        if (!String.isBlank(glavVar3)) {
            queryString += ' AND GL_Account_Variable_3__c = :glavVar3 ';
        }

        if (!String.isBlank(glavVar4)) {
            queryString += ' AND GL_Account_Variable_4__c = :glavVar4 ';
        }

        queryString += 'GROUP BY GL_Account__c '
                + 'HAVING SUM(Year_To_Date__c) != 0 OR MAX(Year_To_Date__c) != 0 OR MIN(Year_To_Date__c) != 0';

        return Database.query(queryString);
    }

    public static List<GL_Account__c> getGlAccountsForTrialBalanceReport() {
        List<GL_Account__c> result = [
            SELECT  Id, Type__c, Sub_Type_1__c, Sub_Type_2__c, Name
            FROM GL_Account__c
            WHERE (
                Type__c IN ('Revenue', 'Expense')
                OR (
                    Type__c = 'Balance Sheet'
                    AND Sub_Type_1__c IN ('Assets', 'Liabilities', 'Owners Equity')
                )
            )
            ORDER BY Name ASC
            LIMIT 50000
        ];
        return result;
    }

    public static List<GL_Account__c> getGlAccountsForCashFlowStatementReport() {
        List<GL_Account__c> result = [
            SELECT  Id,
                    Name,
                    Type__c,
                    Bank__c,
                    Sub_Type_1__c,
                    Sub_Type_2__c
            FROM GL_Account__c
            WHERE Bank__c = TRUE ORDER BY Name ASC
            LIMIT 50000
        ];
        return result;
    }

    public static Integer countActiveGlAccounts(List<String> types) {
        return [SELECT COUNT() FROM GL_Account__c WHERE Type__c IN :types AND Active__c = TRUE LIMIT 50000];
    }

    public static List<GL_Account__c> getAllGlAccounts() {
        return [SELECT Id, Name FROM GL_Account__c LIMIT 50000];
    }

    public static Integer getInputGLAccountsCount() {
        return [SELECT COUNT() FROM GL_Account__c WHERE GL_Category__c = 'Input VAT'];
    }

    public static Integer getOutputGLAccountsCount() {
        return [SELECT COUNT() FROM GL_Account__c WHERE GL_Category__c = 'Output VAT'];
    }
    /*
    * get the Input and Output gl Accounts. There should only ever be one of each of them
    */
    public static List<GL_Account__c> getInputOutputGLAccounts() {
        List<String> glCategories = new List<String>{'Input VAT', 'Output VAT'};
        List<GL_Account__c> ioGlAccts = [SELECT Id, GL_Category__c FROM GL_Account__c WHERE GL_Category__c IN :glCategories];
        return ioGlAccts;
    }

    /*
    * Given a list of GL_Account__c, return a map of the object's type as a String to the number of that type in the given List
    * Created as a way to consolidate queries.
    */
    public static Map<String, Integer> countGLAccountsByGlCategory(List<GL_Account__c> glAccounts) {
        Map<String, Integer> typeToCountofType = new Map<String, Integer>();
        for (GL_Account__c aGlAccount : glAccounts) {
            //do not count null
            if (aGlAccount.GL_Category__c == null) {
                continue;
            }
            //add the type string to the map if necessary
            Integer glCategoryCount = typeToCountOfType.get(aGlAccount.GL_Category__c);
            if (glCategoryCount == null) {
                typeToCountOfType.put(aGlAccount.GL_Category__c, 1);
                continue;
            }
            //otherwise just increment the count
            typeToCountOfType.put(aGlAccount.GL_Category__c, glCategoryCount++);
        }
        return typeToCountOfType;
    }

    public static List<GL_Account__c> getGlAccountsById(Set<Id> ids) {
        List<GL_Account__c> result = [
            SELECT  Id,
                    Name,
                    Bank__c,
                    Type__c,
                    Sub_Type_1__c,
                    Mileage_Account__c,
                    Mileage_Rate__c,
                    GL_Category__c
            FROM GL_Account__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static Map<Id, AggregateResult> getGLAccountsWithFinCubesCount(Set<Id> glAccountIds) {
        return new Map<Id, AggregateResult>([
            SELECT COUNT(Id), GL_Account__c Id
            FROM Financial_Cube__c
            WHERE GL_Account__c IN :glAccountIds
            GROUP BY GL_Account__c
            HAVING COUNT(Id) > 0]);
    }

    public static Map<Id, Map<Id, AggregateResult>> getGLAccountsWithFinCubesCount(Set<Id> glAccountIds, Set<Id> ledgerIds) {
        Map<Id, Map<Id, AggregateResult>> results = new Map<Id, Map<Id, AggregateResult>>();
        List<AggregateResult> aggregateResults = [
                SELECT GL_Account__c glAccountId, COUNT(Id), Ledger__c ledgerId
                FROM Financial_Cube__c
                WHERE GL_Account__c IN :glAccountIds AND Ledger__c IN :ledgerIds
                GROUP BY GL_Account__c, Ledger__c
                HAVING COUNT(Id) > 0
        ];
        for (AggregateResult aggregateRes : aggregateResults) {
            Id ledgerId = (Id) aggregateRes.get('ledgerId');
            Id glAccountId = (Id) aggregateRes.get('glAccountId');
            if (!results.containsKey(ledgerId)) {
                results.put(ledgerId, new Map<Id, AggregateResult>());
            }
            results.get(ledgerId).put(glAccountId, aggregateRes);
        }
        return results;
    }

    public static Map<Id,GL_Account__c> getGlAccountMileageById(Set<Id> ids) {
        return new Map<Id,GL_Account__c>([
            SELECT  Id,
                    Name,
                    Mileage_Account__c,
                    Mileage_Rate__c
            FROM GL_Account__c
            WHERE Id IN :ids
            AND Mileage_Rate__c != NULL
            AND Mileage_Account__c = TRUE
        ]);
    }

    public static List<GL_Account__c> getGlAccountsByName(List<String> glAccountNames) {
        List<GL_Account__c> result = [
            SELECT  Id, Name
            FROM GL_Account__c
            WHERE Name IN :glAccountNames
        ];
        return result;
    }

    public static List<GL_Account__c> getBankGlAccounts() {
        List<GL_Account__c> result = [
                SELECT Id, Name, Active__c, Bank__c
                FROM GL_Account__c
                WHERE Bank__c = TRUE
                AND Active__c = TRUE
                ORDER BY Name ASC
                LIMIT 50000
        ];
        return result;
    }

    public static List<Accounting_Variable__c> getGLAVsById(Set<Id> ids) {
        List<Accounting_Variable__c> result = [
            SELECT  Id, Type__c, Name
            FROM Accounting_Variable__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Accounting_Variable__c> getGLAVsByName(Set<String> names) {
        List<Accounting_Variable__c> result = [
            SELECT  Id, Type__c, Name
            FROM Accounting_Variable__c
            WHERE Name IN :names
        ];
        return result;
    }

    public static List<Bank_Deposit__c> getBankDepositsById(Set<Id> ids) {
        List<Bank_Deposit__c> result = [
            SELECT  Id, Bank_Transaction__c,
                    (SELECT Id FROM Cash_Receipts__r LIMIT 1),
                    (SELECT Id FROM Journal_Entry_Lines__r LIMIT 1)
            FROM Bank_Deposit__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static Bank_Reconciliation2__c getBankReconciliationById(Id bankRecId) {
        List<Bank_Reconciliation2__c> BankRecs = new List<Bank_Reconciliation2__c>();
        String currencyField = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? 'CurrencyIsoCode, ' : '';
        String query = 
                'SELECT ' + 
                currencyField + 
                'Id, ' +
                'Ledger__c ,' +
                'Bank_Account__c, ' +
                'Bank_Account__r.Name, ' +
                'Type__c, ' +
                'End_Date__c, ' +
                'Status__c, ' +
                'GL_Account_Variable_1__c, ' +
                'GL_Account_Variable_2__c, ' +
                'GL_Account_Variable_3__c, ' +
                'GL_Account_Variable_4__c ' +
            'FROM Bank_Reconciliation2__c ' +
            'WHERE Id = :bankRecId';
        List<Bank_Reconciliation2__c> result = (List<Bank_Reconciliation2__c>) Database.query(query);
        return result[0];
    }

    public static List<Bank_Reconciliation2__c> getBankReconciliationsById(Set<Id> ids) {
        List<Bank_Reconciliation2__c> result = [
            SELECT  Id,
                    (SELECT Id FROM Cash_Disbursements__r LIMIT 1),
                    (SELECT Id FROM Cash_Receipts__r LIMIT 1),
                    (SELECT Id FROM Bank_Deposits__r LIMIT 1),
                    (SELECT Id FROM Journal_Entry_Lines__r LIMIT 1)
            FROM Bank_Reconciliation2__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Uncleared_Bank_Reconciliation_Line__c> getUnclearedBankRecLinesByBankRecId(Set<Id> ids) {
        List<String> queryFields = new List<String>{
            'Id',
            'Amount__c',
            'Bank_Deposit__c',
            'Bank_Reconciliation__c',
            'Cash_Disbursement__c',
            'Cash_Receipt__c',
            'Cleared_Date__c',
            'Date__c',
            'Description__c',
            'Journal_Entry_Line__c',
            'Payee_Id__c',
            'Payee_Name__c',
            'Reference__c',
            'Related_Source_Document__c',
            'Type__c'
        };        
        if (MultiCurrencyHandler.isMultiCurrencyEnabled == true) {
            queryFields.add('CurrencyIsoCode');
        }

        String query = 'SELECT ' + String.join(queryFields, ', ') + ' FROM Uncleared_Bank_Reconciliation_Line__c WHERE Bank_Reconciliation__c IN :ids ';
        List<Uncleared_Bank_Reconciliation_Line__c> result = (List<Uncleared_Bank_Reconciliation_Line__c>) Database.query(query);
        return result;                
    }

    public static List<Bank_Reconciliation2__c> getBankRecsById(Set<Id> ids) {
        String currencyField = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? 'CurrencyIsoCode, ' : '';
        String ledgerRelatedCurrencyField = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? 'Ledger__r.CurrencyIsoCode, ' : '';
        String query =
            'SELECT ' +
                currencyField +
                ledgerRelatedCurrencyField +
                'Id, ' +
            	'Name, '+
                'Ledger__c ,' +
                'Ledger__r.Name, ' +
                'Bank_Account__c, ' +
                'Bank_Account__r.Name, ' +
                'End_Date__c, ' +
                'Type__c, ' +
                'Beginning_Balance__c, ' +
                'Calculated_Ending_Balance__c, ' +
                'Calculated_GL_Balance__c, ' +
                'Cleared_Deposits__c, ' +
                'Cleared_Disbursements__c, ' +
                'UnCleared_Deposits__c, ' +
                'UnCleared_Payments__c, ' +
                'GL_Account_Variable_1__c, ' +
                'GL_Account_Variable_1__r.Name, ' +
                'GL_Account_Variable_2__c, ' +
                'GL_Account_Variable_2__r.Name, ' +
                'GL_Account_Variable_3__c, ' +
                'GL_Account_Variable_3__r.Name, ' +
                'GL_Account_Variable_4__c, ' +
                'GL_Account_Variable_4__r.Name, ' +
                'LastModifiedBy.Name, ' +
                'LastModifiedDate ' +
            'FROM Bank_Reconciliation2__c ' +
            'WHERE Id IN :ids ';
        List<Bank_Reconciliation2__c> result = (List<Bank_Reconciliation2__c>) Database.query(query);
        return result;
    }

    public static List<Bank_Reconciliation2__c> getRelatedBankRecs(Bank_Reconciliation2__c bankRec) {
        return getRelatedBankRecs(bankRec, false, false, false);
    }

    public static List<Bank_Reconciliation2__c> getRelatedBankRecs(Bank_Reconciliation2__c bankRec, Boolean includeStatementEndingDate, Boolean includePassedInBankRec, Boolean orderByEndDateDESC) {
        Id brecId = bankRec.Id;
        Id accountId = bankRec.Bank_Account__c;
        Id glav1 = bankRec.GL_Account_Variable_1__c;
        Id glav2 = bankRec.GL_Account_Variable_2__c;
        Id glav3 = bankRec.GL_Account_Variable_3__c;
        Id glav4 = bankRec.GL_Account_Variable_4__c;
        Id ledgerId = bankRec.Ledger__c;
        String currencyIsoCode;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            currencyIsoCode = (String)bankRec.get('CurrencyIsoCode');
        }
        Date endingDate = includeStatementEndingDate == true ? bankRec.End_Date__c : null;
        
        string theQuery = 'SELECT Id, End_Date__c, Status__c, Bank_Account__c, GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, ' +
                            'GL_Account_Variable_4__c, Ledger__c, Override_Beginning_Balance__c, Ending_Balance__c, Type__c, Calculated_Ending_Balance__c';
        
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            theQuery += ', CurrencyIsoCode';
        }
        theQuery += ' FROM Bank_Reconciliation2__c' +
        ' WHERE Bank_Account__c = :accountId' +
        ' AND GL_Account_Variable_1__c = :glav1' + 
        ' AND GL_Account_Variable_2__c = :glav2' + 
        ' AND GL_Account_Variable_3__c = :glav3' + 
        ' AND GL_Account_Variable_4__c = :glav4' + 
        ' AND Ledger__c = :ledgerId';

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            theQuery += ' AND CurrencyIsoCode = :currencyIsoCode';
        }
        if (includeStatementEndingDate == true) {
            theQuery += ' AND End_Date__c = :endingDate';
        }
        if(!includePassedInBankRec){
            theQuery += ' AND Id != :brecId'; 
        }

        theQuery += ' AND Modern_BR__c = true';
       
        if (orderByEndDateDESC) {
            theQuery += ' ORDER BY End_Date__c DESC';
        } else {
            theQuery += ' ORDER BY End_Date__c ASC';
        }
        
        List<Bank_Reconciliation2__c> result = Database.query(theQuery);
        return result;
    }
  
    public static List<AggregateResult> getCashReceiptsAmountSumAndLedgerAmountSum(Id queryId, SObjectField whereField) {
        return Database.query(
            'SELECT SUM(Amount_Number__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' +
                'FROM Cash_Receipt__c ' +
                'WHERE ' + whereField + ' = :queryId'
        );
    }

    public static Map<Id,Decimal> getCRLedgerAmountSumByBankDep(Set<Id> queryIds) {
        Map<Id, Decimal> results = new Map<Id, Decimal>();
        for(AggregateResult aR : Database.query(
            'SELECT Bank_Deposit__c Id, SUM(Ledger_Amount__c) ledgerAmountSum ' +
            ' FROM Cash_Receipt__c ' +
            'WHERE Bank_Deposit__c in :queryIds ' +
            'GROUP BY Bank_Deposit__c'
        )){
            results.put((Id)aR.get('Id'), (Decimal)aR.get('ledgerAmountSum'));
        }

        return results;
    }

    public static List<AggregateResult> getCashDisbursementsAmountSumAndLedgerAmountSum(Id queryId, SObjectField whereField) {
        return Database.query(
            'SELECT SUM(Amount__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' +
                'FROM Cash_Disbursement__c ' +
                'WHERE ' + whereField + ' = :queryId'
        );
    }

    public static List<AggregateResult> getDebitJEAmountSumAndLedgerAmountSum(Id queryId, SObjectField whereField) {
        return Database.query(
            'SELECT SUM(Amount_Number__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' +
                'FROM Journal_Entry_Line__c ' +
                'WHERE ' + whereField + ' = :queryId AND Debit__c != NULL'
        );
    }

    public static Map<Id,Decimal> getDebitJELedgerAmountSumByBankDep(Set<Id> queryIds) {
        Map<Id, Decimal> results = new Map<Id, Decimal>();
        for(AggregateResult aR : Database.query(
            'SELECT Bank_Deposit__c Id, SUM(Ledger_Amount__c) ledgerAmountSum ' + 
            'FROM Journal_Entry_Line__c ' + 
            'WHERE Bank_Deposit__c in :queryIds ' + 
            'AND Debit__c != NULL ' + 
            'GROUP BY Bank_Deposit__c'  
        )){
            results.put((Id)aR.get('Id'), (Decimal)aR.get('ledgerAmountSum'));
        }
        return results;
    }

    public static List<AggregateResult> getCreditJEAmountSumAndLedgerAmountSum(Id queryId, SObjectField whereField) {
        return Database.query(
            'SELECT SUM(Amount_Number__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' +
                'FROM Journal_Entry_Line__c ' +
                'WHERE ' + whereField + ' = :queryId AND Credit__c != NULL'
        );
    }

    public static Map<Id,Decimal> getCreditJELedgerAmountSumByBankDep(Set<Id> queryIds) {
        Map<Id, Decimal> results = new Map<Id, Decimal>();
        for(AggregateResult aR : Database.query(
            'SELECT Bank_Deposit__c Id, SUM(Ledger_Amount__c) ledgerAmountSum ' + 
            'FROM Journal_Entry_Line__c ' + 
            'WHERE Bank_Deposit__c in :queryIds ' + 
            'AND Credit__c != NULL ' + 
            'GROUP BY Bank_Deposit__c'  
        )){
            results.put((Id)aR.get('Id'), (Decimal)aR.get('ledgerAmountSum'));
        }
        return results;
    }

    public static Decimal getCashReceiptAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Cash_Receipt__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' >= 0')[0].get('sum');
    }

    public static Decimal getCashReceiptRefundAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Cash_Receipt__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' < 0')[0].get('sum');
    }

    public static Decimal getBankDepositAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Bank_Deposit__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' >= 0')[0].get('sum');
    }

    public static Decimal getNegativeBankDepositAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Bank_Deposit__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' < 0')[0].get('sum');
    }

    public static Decimal getJEDebitAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Journal_Entry_Line__c WHERE ' + whereField + ' = :queryId AND Debit__c != NULL')[0].get('sum');
    }

    public static Decimal getCashDisbursementAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Cash_Disbursement__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' >= 0')[0].get('sum');
    }

    public static Decimal getNegativeCashDisbursementAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Cash_Disbursement__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' < 0')[0].get('sum');
    }

    public static Decimal getJECreditAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Journal_Entry_Line__c WHERE ' + whereField + ' = :queryId AND Credit__c != NULL')[0].get('sum');
    }

    public static Decimal getBankDisbursementAmount(Id queryId, SObjectField amountField, SObjectField whereField) {
        return (Decimal) Database.query('SELECT SUM(' + amountField + ') sum FROM Bank_Disbursement__c WHERE ' + whereField + ' = :queryId AND ' + amountField + ' >= 0')[0].get('sum');
    }

    public static List<Billing_Credit_Memo__c> getBillingCreditMemosByMasterRecordId(Set<Id> invoiceIds, String periodName) {
        List<Billing_Credit_Memo__c> result = [
            SELECT Id,
                Name,
                Amount__c,
                Accounting_Period__r.Name,
                Billing_Invoice__c,
                Billing_Invoice__r.Total__c,
                Billing_Credit_Memo__c,
                Billing_Credit_Memo__r.Total__c,
                Billing_Credit_Memo__r.Name,
                CreatedDate
            FROM Billing_Credit_Memo__c
            WHERE (Billing_Invoice__c IN :invoiceIds
            OR Billing_Credit_Memo__c IN :invoiceIds)
            AND Accounting_Period__r.Name <= :periodName
            ORDER BY CreatedDate DESC
        ];
        return result;
    }

    public static List<Billing_Credit_Memo__c> getBillingCreditMemosByInvoiceId(Set<Id> invoiceIds) {
        List<Billing_Credit_Memo__c> result = [
            SELECT Id,
                Name,
                Amount__c,
                Accounting_Period__c,
                Accounting_Period__r.Name,
                Billing_Invoice__r.Total__c,
                Billing_Invoice__c,
                Billing_Credit_Memo__c,
                Billing_Credit_Memo__r.Total__c
            FROM Billing_Credit_Memo__c
            WHERE Billing_Invoice__c IN :invoiceIds
            ORDER BY CreatedDate DESC
        ];
        return result;
    }

    public static List<Billing_Cash_Receipt__c> getBillingCashReceiptsByIdForUpdate(Set<Id> ids) {
        List<Billing_Cash_Receipt__c> result = [
            SELECT  Id,
                    Status__c,
                    Accounting_Period__c,
                    Accounting_Period__r.Status__c,
                    Cash_Receipt__r.Ledger__c
            FROM Billing_Cash_Receipt__c
            WHERE Id IN :ids FOR UPDATE
        ];
        return result;
    }

    public static List<Billing_Cash_Receipt__c> getBillingCashReceiptsByIdOrderByPeriod(Set<Id> ids) {
        List<Billing_Cash_Receipt__c> result = [
            SELECT  Id,
                CreatedDate,
                Status__c,
                Accounting_Period__c,
                Accounting_Period__r.Status__c,
                Cash_Receipt__r.Ledger__c,
                Cash_Receipt__r.Credit_GL_Account__c,
                Cash_Receipt__r.Currency_Conversion_Rate__c,
                Billing__r.Ledger__c,
                Billing__c,
                Applied_Amount__c
            FROM Billing_Cash_Receipt__c
            WHERE Id IN :ids
            ORDER BY  CreatedDate ASC
        ];
        return result;
    }

    public static Map<Id, AggregateResult> getBillingCreditMemoInvoiceSumByBilling(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT Billing_Invoice__c Id, SUM(Amount_Number__c) SUM
            FROM Billing_Credit_Memo__c
            WHERE Billing_Invoice__c IN :ids
            GROUP BY Billing_Invoice__c]);
    }

    public static Map<Id, AggregateResult> getBillingCreditMemoMemoSumByBilling(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT Billing_Credit_Memo__c Id, SUM(Amount_Number__c) SUM
            FROM Billing_Credit_Memo__c
            WHERE Billing_Credit_Memo__c IN :ids
            GROUP BY Billing_Credit_Memo__c]);
    }
    
    public static List<AggregateResult> getBillingCashReceiptsByRelatedBillingCount(Set<Id> ids) {
        return [SELECT COUNT(Id) recCount, Billing__c
                FROM Billing_Cash_Receipt__c 
                WHERE Billing__c IN :ids
                GROUP BY Billing__c];
    }
    
    //Query all the relevant Billing Credit Memos and Billing Cash Receipts
    public static List<Billing__c> getBillingCashReceiptsAndBillingCreditMemos(Set<Id> ids) {

        return [
            SELECT Id , Name , Paid_Date__c , Balance__c , Total__c ,
                    (SELECT Id, Applied_Date__c FROM Billing_Cash_Receipts__r WHERE Applied_Date__c != NULL ORDER BY Applied_Date__c DESC LIMIT 1),
                    (SELECT Id, Applied_Date__c FROM Billing_Credit_Memos__r WHERE Applied_Date__c != NULL ORDER BY Applied_Date__c DESC LIMIT 1),
                    (SELECT Id, Applied_Date__c FROM Billing_Credit_Memos1__r WHERE Applied_Date__c != NULL ORDER BY Applied_Date__c DESC LIMIT 1)
            FROM Billing__c
            WHERE Id IN :ids
        ];
     }

    public static Map<Id, AggregateResult> getBillingCreditMemoMaxPeriodByBilling(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
        [SELECT Billing_Credit_Memo__c Id, MAX(Accounting_Period__r.Name) MAX
        FROM Billing_Credit_Memo__c
        WHERE Billing_Credit_Memo__c IN :ids
        GROUP BY Billing_Credit_Memo__c]);
    }

    public static Map<Id, AggregateResult> getBillingCreditMemoInvoiceMaxPeriodByBilling(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
        [SELECT Billing_Invoice__c Id, MAX(Accounting_Period__r.Name) MAX
        FROM Billing_Credit_Memo__c
        WHERE Billing_Invoice__c IN :ids
        GROUP BY Billing_Invoice__c]);
    }

    public static Map<Id, AggregateResult> getBillingCashReceiptsMaxPeriodByBilling(Set<Id> ids) {
        return new Map<Id, AggregateResult> (
        [SELECT Billing__c Id, MAX(Accounting_Period__r.Name) MAX
        FROM Billing_Cash_Receipt__c
        WHERE Billing__c IN :ids
        GROUP BY Billing__c]);
    }

    public static List<Billing_Cash_Receipt__c> getBillingCashReceiptsByRelatedBillingId(Set<Id> ids, String periodName) {
        List<Billing_Cash_Receipt__c> result = [
                SELECT  Id,
                        Accounting_Period__r.Name,
                        Applied_Amount__c,
                        Adjustment_Amount__c,
                        Billing__c,
                        Billing__r.Total__c,
                        Billing__r.Ledger__c,
                        Status__c
                FROM Billing_Cash_Receipt__c
                WHERE Billing__c IN :ids
                AND Accounting_Period__r.Name <= :periodName
        ];
        return result;
    }

    public static List<Billing_Cash_Receipt__c> getBillingCashReceiptsByBillingId(Set<Id> ids) {
        List<Billing_Cash_Receipt__c> result = [
            SELECT  Id,
                Accounting_Period__c,
                Accounting_Period__r.Name,
                Applied_Amount__c,
                Adjustment_Amount__c,
                Billing__c,
                Billing__r.Total__c,
                Billing__r.Ledger__c,
                Cash_Receipt__r.Void__c,
                Status__c,
                (SELECT Id,
                    Billing_Cash_Receipt__c,
                    Billing_Line__c,
                    Transaction_Key__c,
                    Amount__c,
                    Foreign_Amount__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    GL_Account__c,
                    Time_Card_Variable_1__c,
                    Time_Card_Variable_2__c,
                    Project__c,
                    Project_Task__c,
                    Product__c,
                    Note__c,
                    Ledger__c
                FROM Transactions__r)
            FROM Billing_Cash_Receipt__c
            WHERE Billing__c IN :ids
        ];
        return result;
    }

    public static List<AggregateResult> getBillingCashReceiptsByRelatedCashReceiptCount(Set<Id> ids) {
        return [SELECT COUNT(Id) recCount, Cash_Receipt__c
                FROM Billing_Cash_Receipt__c 
                WHERE Cash_Receipt__c IN :ids
                GROUP BY Cash_Receipt__c];
    }

    public static List<Billing_Aging_History__c> getBillingAHByRelatedBillingIdAndAccPeriodId(Set<Id> ids, Id accPeriod) {
        List<Billing_Aging_History__c> result = [
                SELECT  Id, Accounting_Period__c, Amount__c, Billing__c
                FROM Billing_Aging_History__c
                WHERE Billing__c IN :ids
                AND Accounting_Period__c = :accPeriod
        ];
        return result;
    }

    public static List<AP_Aging_History__c> getAPAgingHistoryByRelatedAPIdAndAccPeriodId(Set<Id> ids, Id accPeriod) {
        List<AP_Aging_History__c> result = [
                SELECT  Id, Accounting_Period__c, Amount__c, Account_Payable__c
                FROM AP_Aging_History__c
                WHERE Account_Payable__c IN :ids
                AND Accounting_Period__c = :accPeriod
        ];
        return result;
    }

    public static List<AggregateResult> countTransactionsByAmortizationEntry(Set<Id> amortizationEntryIds) {
        return [
            SELECT COUNT(Id) totalTransactionNmb, Scheduled_Revenue_Expense__c sourceDoc
            FROM Transaction__c
            WHERE Scheduled_Revenue_Expense__c IN :amortizationEntryIds
            GROUP BY Scheduled_Revenue_Expense__c
        ];
    }

    public static List<AggregateResult> countTransactionsByCashReceipt(Set<Id> crIds) {
        return [
            SELECT COUNT(Id) totalTransactionNmb, Cash_Receipt__c sourceDoc
            FROM Transaction__c
            WHERE Cash_Receipt__c IN :crIds
            GROUP BY Cash_Receipt__c
        ];
    }

    public static List<AggregateResult> countTransactionsByAccountingPeriod(List<Accounting_Period__c> accountingPeriods) {
        return [
            SELECT COUNT(Id) totalTransactionNmb, Accounting_Period__c accountingPeriod, Accounting_Period__r.Name periodName
            FROM Transaction__c
            WHERE Accounting_Period__c IN :accountingPeriods
            GROUP BY Accounting_Period__c, Accounting_Period__r.Name
        ];
    }

    public static List<Transaction__c> getTransactionsById(Set<Id> ids) {
        List<String> queryFields = new List<String>{
            'Id'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Transaction__c>) Database.query(theQuery.toSOQL());
    }

    public static List<Transaction__c> getTransactionsByBcr(List<Billing_Cash_Receipt__c> bcrList) {
        return [
            SELECT Id, Billing_Cash_Receipt__c
            FROM Transaction__c
            WHERE Billing_Cash_Receipt__c IN :bcrList
        ];
    }

    public static List<Transaction__c> getTransactionsByApd(List<AP_Disbursement__c> apdList) {
        return [
            SELECT Id, AP_Disbursement__c
            FROM Transaction__c
            WHERE AP_Disbursement__c IN :apdList
        ];
    }
    
    public static List<Billing__c> getBillingsById(Set<String> billingFields, Set<Id> ids) {
        List<String> conditions = new List<String>{'Id IN: ids'};
        return Database.query(
            String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(billingFields, ', '),
                PACKAGE_QUALIFIER + 'Billing__c',
                ' WHERE ' + String.join(conditions, ' AND ')
        })
        );
    }
    
    public static List<Billing__c> getBillingsById(Set<Id> ids) {
        List<Billing__c> result = [
            SELECT  Id,
                    Name,
                    LastModifiedDate,
                    Date__c,
                    Customer__c,
                    Customer__r.GL_Account_Variable_1__c,
                    Customer__r.GL_Account_Variable_2__c,
                    Customer__r.GL_Account_Variable_3__c,
                    Customer__r.GL_Account_Variable_4__c,
                    Accounting_Period__c,
                    Billing_Format__c,
                    Ledger__c,
                    Ledger_Amount__c,
                    Locked_In_AvaTax__c,
                    Billing_Street__c,
                    Billing_Country__c,
                    Billing_State__c,
                    Billing_PostalCode__c,
                    Billing_City__c,
                    Shipping_Street__c,
                    Shipping_Country__c,
                    Shipping_State__c,
                    Shipping_PostalCode__c,
                    Shipping_City__c,
                    OwnerId,
                    Billing_Contact__c,
                    Billing_Cycle_Start_Date__c,
                    Billing_Cycle_End_Date__c,
                    Balance__c, 
                    Payment_Processor__c, 
                    Total__c, 
                    PO_Number__c, 
                    Billing_Comment__c,
                    Sub_Total__c,
                    Currency_Conversion_Rate__c,
                    Status__c,
                    (SELECT Id, Name FROM Project_Billing_Lines__r LIMIT 1)
            FROM Billing__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Billing__c> getBillingsWithCurrencyById(Set<Id> ids) {
        List<String> fields = new List<String> {
            'Id',
            'Name',
            'Date__c',
            'Customer__c',
            'Accounting_Period__c',
            'Ledger__c',
            'Ledger_Amount__c',
            'Balance__c', 
            'Payment_Processor__c', 
            'Total__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('CurrencyIsoCode');
        }
        String q = 'SELECT ' + String.join(fields, ',') + ' FROM Billing__c WHERE Id IN :ids';
        return (List<Billing__c>) Database.query(q);
    }

    public static List<Billing__c> getRollupsOnBillingById(Set<Id> ids) {
        List<Billing__c> result = [
            SELECT  Id,
                    Ledger__c,
                    Received_Amount__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Total__c
            FROM Billing__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Billing__c> getBillingsBySelectedBillings(List<Billing__c> selectedBillings) {
        List<Billing__c> result = [
            SELECT  Id,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Billing_Contact__c,
                    Billing_Contact__r.FirstName,
                    Billing_Contact__r.LastName,
                    Billing_Contact__r.Email,
                    Billing_Format__c,
                    Billing_Format__r.Default_Email_Template__c,
                    Billing_Format__r.ReplyTo_Email__c,
                    Billing_Format__r.Visualforce_PDF_Page__c,
                    Billing_Format__r.Sort_Field__c,
                    Billing_Format__r.Org_Wide_Email_Address__c,
                    Proprietary_Billing_Number__c,
                    Status__c,
                    Date__c,
                    PDF_Email_Status__c
            FROM Billing__c
            WHERE Id IN :selectedBillings
        ];
        return result;
    }

    public static List<Billing__c> getBillingsByIdForUpdate(Set<Id> ids) {
        List<Billing__c> result = [
            SELECT Id, Name, Status__c, LastModifiedDate
            FROM Billing__c
            WHERE Id IN :ids FOR UPDATE
        ];
        return result;
    }

    public static List<GL_Account_Reporting_Group_Line__c> getGlAccountReportingGroupLinesByMasterId(Set<Id> masterIds) {
        List<GL_Account_Reporting_Group_Line__c> result = [
            SELECT  Id,
                    GL_Account_Reporting_Group__c,
                    GL_Account__c,
                    GL_Account_Reporting_Group__r.Type__c,
                    Type__c
            FROM GL_Account_Reporting_Group_Line__c
            WHERE GL_Account_Reporting_Group__c IN :masterIds
        ];
        return result;
    }

    public static List<GL_Account_Reporting_Group__c> getGlAccountReportingGroupByIdWithRelatedLines(Set<Id> ids, Set<Id> exceptLineIds) {
        if (exceptLineIds == null) {
            exceptLineIds = new Set<Id>();
        }
        List<GL_Account_Reporting_Group__c> result = [
            SELECT  Id,
                    (
                        SELECT Id, GL_Account__c, GL_Account_Reporting_Group__c
                        FROM GL_Account_Reporting_Group_Lines__r
                        WHERE Id NOT IN :exceptLineIds
                    )
            FROM GL_Account_Reporting_Group__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<GL_Account_Reporting_Group__c> getGlAccountReportingGroupWithCashFlowRelatedLines(Set<Id> ids) {
        List<GL_Account_Reporting_Group__c> result = [
            SELECT  Id,
                    (
                        SELECT Id
                        FROM GL_Account_Reporting_Group_Lines__r
                        WHERE GL_Account__r.Type__c = 'Cash Flow'
                        LIMIT 1
                    )
            FROM GL_Account_Reporting_Group__c
            WHERE Id IN :ids
        ];

        return result;
    }

    public static Map<Id, Billing_Line__c> getBillingLinesByMasterId(Set<Id> masterIds) {
        return new Map<Id, Billing_Line__c>([
            SELECT Id,
                Billing__c,
                Ledger__c,
                Billing__r.Ledger__c,
                Product__c,
                Hours_Units__c,
                Rate__c,
                Tax_Amount2__c,
                Total__c,
                Project__c,
                Revenue_GL_Account__c,
                Project_Task__c,
                GL_Account_Variable_1__c,
                GL_Account_Variable_2__c,
                GL_Account_Variable_3__c,
                GL_Account_Variable_4__c,
                Sub_Total__c,
                Tax_Line__c,
                Tax_Group__c,
                Billing__r.Currency_Conversion_Rate__c,
                Time_Card_Variable_1__c,
                Time_Card_Variable_2__c
            FROM Billing_Line__c
            WHERE Billing__c IN :masterIds
        ]);
    }

    public static Set<Id> getExpenseLinesByBillingIds(Set<Id> ids) {
        return new Map<Id,Expense_Line__c>([SELECT Id
                FROM Expense_Line__c
                WHERE Billing_Line__c IN :ids]).keySet();
    }

    public static External_Settings__mdt queryExternalSettingsByDeveloperName(String devName) {
        External_Settings__mdt extSetting = [
            SELECT Value_1__c, Value_2__c, Value_3__c, Value_4__c, Value_5__c
            FROM External_Settings__mdt
            WHERE DeveloperName = :devName
        ];
        return extSetting;
    }

    public static List<AggregateResult> getMostRecentFinancialCubesByLedgerId(Set<Id> ledgerIds) {
        List<AggregateResult> result = [
            SELECT MAX(CREATEDDATE) MAX, Ledger__c
            FROM Financial_Cube__c
            WHERE Ledger__c IN :ledgerIds
            GROUP BY Ledger__c LIMIT 200
        ];
        return result;
    }

    public static List<Product2> getProductsById(Set<Id> ids) {
        List<Product2> result = [
            SELECT  Id,
                    Name,
                    ProductCode,
                    Tax_Code__c,
                    Description,
                    Tax_Rate__c,
                    Tax_Group__c,
                    Accounting_Type__c,
                    Revenue_GL_Account__c,
                    Expense_GL_Account__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Inventory_GL_Account__c,
                    Inventory_Product__c,
                    Inventory_Type__c,
                    Unit_Cost__c
            FROM Product2
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Product2> getProductsByIdWithAccountTaxes(Set<Id> ids, Integer subqueryLimit) {
        List<Product2> result = [
            SELECT  Id,
                    (SELECT Id FROM Account_Taxes__r LIMIT :subqueryLimit)
            FROM Product2
            WHERE Id IN :ids
        ];

        return result;
    }

    public static List<PricebookEntry> getPricebookEntriesByProductAndPriceBookId(Set<Id> productIds, Set<Id> priceBookIds) {
        String currencyField = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? 'CurrencyIsoCode, ' : '';
        String query =
            'SELECT ' + currencyField + 'Id, Product2Id, Pricebook2Id ' +
            'FROM PricebookEntry ' +
            'WHERE IsActive = true ' +
            'AND Product2Id IN :productIds ' +
            'AND Pricebook2Id IN :priceBookIds';
        List<PricebookEntry> result = Database.query(query);
        return result;
    }

    public static Integer countPricebookEntriesByProduct(Set<Id> productIds) {
        Integer result = [
            SELECT COUNT()
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND IsActive = TRUE
        ];
        return result;
    }
    
    public static List<Product_Part__c> getProductPartsByProductId(Set<Id> productIds) {
        List<Product_Part__c> result = [
            SELECT Id,
                Product__c,
                Product__r.Inventory_Type__c,
                Quantity__c,
                Product_Part__r.Id,
                Product_Part__r.Inventory_Product__c,
                Product_Part__r.Inventory_Type__c,
                Product_Part__r.Revenue_GL_Account__c,
                Product_Part__r.Expense_GL_Account__c,
                Product_Part__r.Inventory_GL_Account__c,
                Product_Part__r.Unit_Cost__c,
                Product_Part__r.GL_Account_Variable_1__c,
                Product_Part__r.GL_Account_Variable_2__c,
                Product_Part__r.GL_Account_Variable_3__c,
                Product_Part__r.GL_Account_Variable_4__c
            FROM Product_Part__c WHERE Product__c IN :productIds
        ];
        return result;
    }

    public static Map<Id, AggregateResult> getProductPartsByProductCount(Set<Id> productIds, String inventoryType, Integer countLimit) {
        return new Map<Id, AggregateResult>([
            SELECT Product__c Id, COUNT(Id) recCount
            FROM Product_Part__c 
            WHERE Product__c IN :productIds
            AND Product__r.Inventory_Type__c = :inventoryType
            GROUP BY Product__c
            HAVING COUNT(Id) > :countLimit
        ]);
    }

    public static List<String> getApexPagesByName(Set<String> names) {
        List<String> pages = new List<String>();
        for (ApexPage page : [SELECT Id, Name FROM ApexPage WHERE Name IN :names ORDER BY NameSpacePrefix NULLS FIRST]) {
           pages.add(page.Name);
        }
        return pages;
    }

    public static List<ApexPage> getApexPagesByName(Set<String> pageNames, String namespace) {
        List<ApexPage> result = [
            SELECT Id, Name
            FROM ApexPage
            WHERE NamespacePrefix = :namespace
            AND Name IN :pageNames
        ];
        return result;
    }

    public static List<ApexClass> getApexClassesByName(Set<String> names) {
        List<ApexClass> result = [
            SELECT Id, Name
            FROM ApexClass
            WHERE Name IN :names
            LIMIT :names.size()
        ];
        return result;
    }

    public static List<EmailTemplate> getEmailTemplatesByDeveloperName(Set<String> devNames) {
        List<EmailTemplate> result = [
            SELECT Id, DeveloperName, TemplateType, Subject, Body
            FROM EmailTemplate
            WHERE DeveloperName IN :devNames
            ORDER BY NameSpacePrefix NULLS FIRST
        ];
        return result;
    }


    public static List<String> getEmailTemplatesByDeveloperNameString(Set<String> devNames) {
        List<String> templates = new List<String>();
        for (EmailTemplate template : getEmailTemplatesByDeveloperName(devNames)) {
            templates.add(template.DeveloperName);
        }

        return templates;
    }

    public static List<Payment_Method__c> getAllPaymentMethods() {
        List<Payment_Method__c> result = [
            SELECT  Id,
                    Customer__c,
                    Type__c,
                    Payment_Method_Type__c,
                    Bank_Name__c,
                    Status__c,
                    Default__c,
                    Bank_Account_Type__c,
                    Card_Holder_Name__c,
                    Expiration_Month__c,
                    Expiration_Year__c,
                    Last_Four_Digits__c,
                    Payment_Processor__c,
                    AP_Payment_Method__c
            FROM Payment_Method__c LIMIT 50000
        ];
        return result;
    }

    public static List<Payment_Method__c> getExistedDefaultPaymentMethods(Set<Id> customerIds, Set<Id> exceptPaymentMethodIds) {
        if (exceptPaymentMethodIds == null) {
            exceptPaymentMethodIds = new Set<Id>();
        }
        List<Payment_Method__c> result = [
            SELECT Id, Default__c
            FROM Payment_Method__c
            WHERE Default__c = TRUE
            AND AP_Payment_Method__c = FALSE
            AND Customer__c IN :customerIds
            AND Id NOT IN :exceptPaymentMethodIds LIMIT 10000
        ];
        return result;
    }

    public static Payment_Method__c getCustomerDefaultPaymentMethod(Id customerId) {
        List<Payment_Method__c> result = [
            SELECT Id
            FROM Payment_Method__c
            WHERE Default__c = TRUE
            AND Customer__c = :customerId
            LIMIT 1
        ];
        return result == null || result.isEmpty() ? null : result.get(0);
    }

    public static List<Payment_Method__c> getPaymentMethodsByAccount(Id accountId) {
        List<Payment_Method__c> result = [
            SELECT  
                Id,
                Customer__c,
                Card_Holder_Name__c,
                Type__c,
                Bank_Account_Type__c,
                Bank_Name__c,
                Status__c,
                Default__c,
                Expiration_Month__c,
                Expiration_Year__c,
                Last_Four_Digits__c,
                External_Id__c,
                Verification_Status__c,
                Payment_Method_Type__c,
                CreatedDate
            FROM Payment_Method__c 
            WHERE Customer__c = :accountId 
            ORDER BY CreatedDate ASC
            LIMIT 50000
        ];
        return result;
    }

    public static List<Payment_Method__c> getPaymentMethodsByAccountAndProcessor(Id accountId, Id processorId) {
        List<Payment_Method__c> result = [
            SELECT  
                Id,
                Customer__c,
                Card_Holder_Name__c,
                Type__c,
                Bank_Account_Type__c,
                Bank_Name__c,
                Status__c,
                Default__c,
                Expiration_Month__c,
                Expiration_Year__c,
                Last_Four_Digits__c,
                External_Id__c,
                Verification_Status__c,
                Payment_Method_Type__c,
                CreatedDate,
                Payment_Processor__c
            FROM Payment_Method__c 
            WHERE Customer__c = :accountId 
            AND Payment_Processor__c = :processorId
            ORDER BY CreatedDate ASC
            LIMIT 50000
        ];
        return result;
    }

    public static List<Payment_Method__c> getDefaultPaymentMethodByVendor(Set<Id> vendorIds, List<Id> paymentMethodsToExclude){
        List<String> fieldsToQuery = new List<String>{ 'Id', 'Vendor__c','Vendor__r.Name','Default__c'};

        String queryCondition = 'Vendor__c IN :vendorIds AND Default__c = true AND AP_Payment_Method__c = true';

        if (!paymentMethodsToExclude.isEmpty()) {
            queryCondition += ' AND Id NOT IN :paymentMethodsToExclude';
        }

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        theQuery.assertIsAccessible().setEnforceFLS(false).selectFields(fieldsToQuery).setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }

    public static List<Account> getAccountWhereStripeCustomeIdIsPresent(){
        return [
            SELECT Id, Name, Stripe_Customer_Id__c
            FROM Account
            WHERE Stripe_Customer_Id__c <> NULL
        ];
    }
    public static List<Account> getAccountsBySelectedAccounts(List<Account> selectedAccounts) {
        Map<Id, Account> accountMap = new Map<Id, Account>(selectedAccounts);
        return getAccountsById(accountMap.keySet());
    }

    public static List<Account> getAccountsById(Set<Id> ids) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Phone',
            'Alternate_Payee_Name__c',
            'Account_Payable_Terms__c',
            'Billing_Terms_Name__c',
            'Billing_Days_Due__c',
            'Billing_Discount_Days_Due__c',
            'Billing_Discount_Percent__c',
            'BillingStreet',
            'BillingCity',
            'BillingState',
            'BillingPostalCode',
            'BillingCountry',
            'Billing_Contact__c',
            'Billing_Contact__r.FirstName',
            'Billing_Contact__r.LastName',
            'Billing_Contact__r.Email',
            'ShippingStreet',
            'ShippingCity',
            'ShippingState',
            'ShippingPostalCode',
            'ShippingCountry',
            'Shipping_Contact__c',
            'Billing_Format__c',
            'Outstanding_Statement_Format__c',
            'Activity_Statement_Format__c',
            'Activity_Statement_Format__r.Visualforce_PDF_Page__c',
            'Activity_Statement_Format__r.ReplyTo_Email__c',
            'Activity_Statement_Format__r.Default_Email_Template__c',
            'Activity_Statement_Format__r.Org_Wide_Email_Address__c',
            'Outstanding_Statement_Format__r.Visualforce_PDF_Page__c',
            'Outstanding_Statement_Format__r.ReplyTo_Email__c',
            'Outstanding_Statement_Format__r.Default_Email_Template__c',
            'Outstanding_Statement_Format__r.Org_Wide_Email_Address__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Credit_Card_Vendor__c',
            'VAT_Business_Identification_Number__c',
            'Entity_Use_Code__c',
            'Exemption_Number__c',
            'Default_Form_Category_Id__c',
            'X1099_Vendor__c',
            'Stripe_Customer_Id__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryString = 'SELECT ' + String.join(queryFields, ',') + ' FROM Account WHERE Id IN :ids';
        
        return (List<Account>) Database.query(queryString);
    }

    public static List<Account> getAccountsByName(Set<String> names) {
        List<Account> result = [
            SELECT Id, Name
            FROM Account
            WHERE Name IN :names
        ];
        return result;
    }

    public static List<PermissionSetAssignment> getPermissionSetAssignmentsByAssigneeAndName(Set<Id> assigneeIds, Set<String> permissionSetNames) {
        List<PermissionSetAssignment> result = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :assigneeIds
            AND PermissionSet.Name IN :permissionSetNames
        ];
        return result;
    }

    public static List<Account> getChildAccountsForGivenParent(Id parentAccountId) {
        List<Account> childAccounts = [
            SELECT Id,
                   (SELECT Id, Name FROM ChildAccounts)
            FROM Account
            WHERE Id = :parentAccountId
        ].ChildAccounts;

        return childAccounts;
    }

    public static List<Time_Card__c> getTimeCardsByEmployeeAndTimeCardPeriod(
            Set<Id> employeeIds,
            Set<Id> timeCardPeriodIds,
            Set<Id> ledgerIds
    ) {
        List<Time_Card__c> result = [
            SELECT Id, Time_Card_Period__c, Employee__c, Ledger__c, Type__c
            FROM Time_Card__c
            WHERE Employee__c IN :employeeIds
            AND Time_Card_Period__c IN :timeCardPeriodIds
            AND (Ledger__c IN :ledgerIds OR Ledger__c = NULL)
        ];
        return result;
    }

    public static List<Time_Card_Line__c> getTimeCardLinesById(Set<Id> ids) {
        List<Time_Card_Line__c> result = [
            SELECT Id, Name, Billed__c FROM Time_Card_Line__c WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Time_Card__c> getTimeCardsByIdForUpdate(Set<Id> ids) {
        List<Time_Card__c> result = [
            SELECT Id, Name, Status__c, LastModifiedDate 
            FROM Time_Card__c 
            WHERE Id IN :ids FOR UPDATE
        ];
        return result;
    }

    public static List<Time_Card__c> getTimeCardsById(Set<Id> ids) {
        List<Time_Card__c> result = [
            SELECT Id, LastModifiedDate FROM Time_Card__c WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Time_Card_Line__c> getTimeCardLinesByTimeCardId(Set<Id> ids) {
        return [SELECT Id, Time_Card__c, Project__c, Project_Task__c, Billable__c FROM Time_Card_Line__c WHERE Time_Card__c IN :ids];
    }

    public static List<Time_Card_Accounting_Period__c> getTimeCardAccountingPeriodsByTimeCardPeriod(Set<Id> timeCardPeriodIds) {
        List<Time_Card_Accounting_Period__c> result = [
            SELECT Id FROM Time_Card_Accounting_Period__c WHERE Time_Card_Period__c IN :timeCardPeriodIds
        ];
        return result;
    }

    public static Set<Id> getBillingLinesWithTimeCardDaysById(Set<Id> ids) {
        return new Set<Id>(new Map<Id,AggregateResult>([
                            SELECT Time_Card_Line__c Id
                            FROM Time_Card_Day__c
                            WHERE Billing_Line__c IN :ids
                            GROUP BY Time_Card_Line__c]).keySet());
    }

    public static List<Time_Card_Period__c> getTimeCardPeriodWithTimeCardsById(Set<Id> ids) {
        List<Time_Card_Period__c> result = [
            SELECT  Id,
                    (SELECT Id FROM Time_Cards__r LIMIT 1)
            FROM Time_Card_Period__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Time_Card_Period__c> getTimeCardPeriodsById(Set<Id> ids) {
        List<Time_Card_Period__c> result = [
            SELECT  Id, Start_Date__c, End_Date__c, Status__c
            FROM Time_Card_Period__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Time_Card_Period__c> getTimeCardPeriodsByYear(Set<Integer> years) {
        List<Time_Card_Period__c> result = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Time_Card_Period__c
            WHERE CALENDAR_YEAR(Start_Date__c) IN :years
            OR CALENDAR_YEAR(End_Date__c) IN :years
            LIMIT 50000
        ];
        return result;
    }

    public static List<Time_Card_Day__c> geTimeCardDaysByTimeCardLine(Set<Id> timeCardLineIds) {
        List<Time_Card_Day__c> result = [
            SELECT Id, Date__c, Time_Card_Line__c
            FROM Time_Card_Day__c
            WHERE Time_Card_Line__c IN :timeCardLineIds
        ];
        return result;
    }

    public static List<Dashboard> getDashboardByName(Set<String> names, String namespacePrefix) {
        List<Dashboard> result = [
            SELECT Id
            FROM Dashboard
            WHERE DeveloperName IN :names
            AND NamespacePrefix = :namespacePrefix
        ];
        return result;
    }

    public static Dashboard getAccountingDashboard() {
        Dashboard result = [
                SELECT Id
                FROM Dashboard
                WHERE DeveloperName = 'Accounting'
                AND NamespacePrefix = :PACKAGE_QUALIFIER.replace('_', '')
        ];
        return result;
    }

    public static List<AsyncApexJob> getOpeningClosingPeriodRelatedAsyncApexJobs() {
        String nameSpacePrefix = GlobalVariables.PACKAGE_QUALIFIER.replaceAll('_', '');

        List<AsyncApexJob> runningApexJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE Status IN :GlobalVariables.APEX_JOB_STATUSES
            AND (
                ApexClass.Name IN :AccountingPeriodOpenCloseUtils.openCloseAccountingPeriodClasses
                OR ApexClass.Name IN :AccountingPeriodOpenCloseUtils.archiveAccountingPeriodClasses
            )
            AND ApexClass.NamespacePrefix = :nameSpacePrefix LIMIT 1
        ];

        return runningApexJobs;
    }

    public static List<AsyncApexJob> getAsyncApexJobById(Set<Id> ids) {
        List<AsyncApexJob> jobs = [
            SELECT  Id,
                    CreatedById,
                    Status,
                    NumberOfErrors,
                    JobItemsProcessed,
                    TotalJobItems,
                    CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id IN :ids
        ];

        return jobs;
    }

    public static List<AsyncApexJob> getAsyncApexJobByApexClassIdAndStatus(Set<Id> classIds, Set<String> statuses) {
        List<AsyncApexJob> jobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE Status IN :statuses
            AND ApexClassID IN :classIds
        ];

        return jobs;
    }

    public static List<AsyncApexJob> getAsyncApexJobByApexClassNameAndStatus(Set<String> classNames, Set<String> statuses) {
        List<AsyncApexJob> jobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE Status IN :statuses
            AND ApexClass.Name IN :classNames
        ];

        return jobs;
    }

    public static List<AsyncApexJob> getRecentAsyncApexJobByApexClassNameAndStatus(Set<String> classNames, Set<String> statuses, Datetime timeThreshold) {
        List<AsyncApexJob> jobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE Status IN :statuses
            AND ApexClass.Name IN :classNames
            AND CompletedDate != NULL
            AND CompletedDate > :timeThreshold
        ];

        return jobs;
    }

    public static List<CronTrigger> getCronTriggerByJobName(Set<String> jobName) {
        List<CronTrigger> jobs = [
            SELECT  Id,
                    CronJobDetailId,
                    CronJobDetail.Name,
                    StartTime,
                    EndTime,
                    NextFireTime,
                    State,
                    CreatedById
            FROM CronTrigger
            WHERE CronJobDetail.Name IN :jobName
        ];

        return jobs;
    }

    public static List<CronTrigger> getCronTriggerByJobNamePrefix(String jobNamePrefix) {
        String theQuery =
            'SELECT Id, CronJobDetailId, CronJobDetail.Name, StartTime, EndTime, NextFireTime, State, CreatedById ' +
            'FROM CronTrigger ' +
            'WHERE CronJobDetail.Name LIKE \'%' + String.escapeSingleQuotes(jobNamePrefix) + '%\'';

        return Database.query(theQuery);
    }

    public static List<Contact> getContactById(Set<Id> ids) {
        List<Contact> contacts = [
            SELECT  Id,
                    Name,
                    FirstName,
                    LastName,
                    MobilePhone,
                    Email,
                    MailingStreet,
                    MailingCity,
                    MailingState,
                    MailingPostalCode,
                    MailingCountry,
                    Payable_Days_Due__c
            FROM Contact
            WHERE Id IN :ids
        ];
        return contacts;
    }

    public static List<User> getUserById(Set<Id> ids) {
        List<User> result = [
            SELECT  Id,
                    Name,
                    Street,
                    City,
                    State,
                    PostalCode,
                    Country,
                    Email,
                    IsActive,
                    Payable_Days_Due__c 
            FROM User
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<PackageLicense> licensesByPackagePrefixes(Set<String> prefixes) {
        return [
                SELECT Id, AllowedLicenses, UsedLicenses, ExpirationDate, NamespacePrefix, Status
                FROM PackageLicense
                WHERE NamespacePrefix =: prefixes
        ];
    }

    public static List<User> fetchUsersByPackageLicenseIds(Set<String> prefixes) {
        List<UserPackageLicense> userLicenses = [
                SELECT UserId, User.AccountId, User.FirstName, User.LastName, User.Email, User.Username, User.IsActive
                FROM UserPackageLicense
                WHERE PackageLicense.NamespacePrefix =: prefixes
        ];
        Map<Id, User> usersByIds = new Map<Id, User>();
        for (UserPackageLicense userLicense : userLicenses) {
            usersByIds.put(userLicense.UserId, userLicense.User);
        }

        return usersByIds.values();
    }

    public static List<User> fetchAllUsers() {
        return [
                SELECT Id, AccountId, FirstName, LastName, Email, Username, IsActive
                FROM User
        ];
    }

    public static Organization fetchOrganization() {
        List<Organization> organizations = [
                SELECT Id, IsSandbox, OrganizationType, LanguageLocaleKey, InstanceName, TimeZoneSidKey
                FROM Organization
                LIMIT 1
        ];
        return !organizations.isEmpty() ? organizations[0] : null;
    }

    public static List<Expense_Line__c> getExpenseLinesById(Set<Id> ids) {
        List<Expense_Line__c> result = [
            SELECT Id,
                Billable__c,
                Vendor_Employee_Paid__c,
                Expense_GL_Account__r.Mileage_Account__c,
                Miles__c
            FROM Expense_Line__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static Integer getAccountCount(Boolean isActive, Set<String> accountingTypes) {
        Integer result = [
            SELECT COUNT()
            FROM Account
            WHERE Accounting_Active__c = :isActive
            AND Accounting_Type__c IN :accountingTypes
            LIMIT 2001
        ];
        return result;
    }

    public static List<Ledger__c> getLedgerWithStatementFormatFieldsById(Set<Id> ids) {
        List<Ledger__c> result = [
            SELECT
                Id,
                Name,
                Type__c,
                Billing_Activity_Statement_Format__c,
                Billing_Activity_Statement_Format__r.Visualforce_PDF_Page__c,
                Billing_Activity_Statement_Format__r.ReplyTo_Email__c,
                Billing_Activity_Statement_Format__r.Default_Email_Template__c,
                Billing_Activity_Statement_Format__r.Org_Wide_Email_Address__c,
                Billing_Outstanding_Statement_Format__c,
                Billing_Outstanding_Statement_Format__r.Visualforce_PDF_Page__c,
                Billing_Outstanding_Statement_Format__r.ReplyTo_Email__c,
                Billing_Outstanding_Statement_Format__r.Default_Email_Template__c,
                Billing_Outstanding_Statement_Format__r.Org_Wide_Email_Address__c,
                Default_Bank_Account__c,
                Default_Billing_Format__c,
                Default_Purchase_Order_Format__c,
                Default_Packing_Slip_Format__c
            FROM Ledger__c
            WHERE Id IN :ids
        ];

        return result;
    }

    public static List<Ledger__c> getLedgersById(Set<Id> ids) {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Consolidation_Ledger_ID__c',
            'Accounting_Method__c',
            'Payment_Services_Company_Code__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('CurrencyIsoCode');
        }
        return Database.query(String.format('SELECT {0} FROM Ledger__c WHERE Id IN :ids', new List<String>{
                String.join(fields, ',')
        }));
    }

    public static List<Ledger__c> getLedgers() {
        return getLedgerByType(
            new Set<String>{
                LedgerActions.LEDGER_TYPE_BUDGET,
                LedgerActions.LEDGER_TYPE_TRANSACTIONAL,
                LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET,
                LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL,
                LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
            }
        );
    }

    public static List<AvaTax_License__c> getAvaTaxLicenses(Set<Id> ids) {
        return [
                SELECT Id, Active_AvaTax_Endpoint__c, AvaTax_Account_ID__c, AvaTax_License_Key__c
                FROM AvaTax_License__c
                WHERE Id =: ids
        ];
    }

    public static List<Tax_Settings__c> taxSettingsByMethod(String method) {
        return [
                SELECT Id
                FROM Tax_Settings__c
                WHERE Tax_Settings_Method__c =: method
                LIMIT 1
        ];
    }

    public static List<Tax_Settings__c> taxSettingsByIdsAndMethods(Set<Id> ids, Set<String> methods) {
        return [
                SELECT Id,
                        AvaTax_License__c,
                        AvaTax_License__r.Active_AvaTax_Endpoint__c,
                        AvaTax_License__r.AvaTax_Account_ID__c,
                        AvaTax_License__r.AvaTax_License_Key__c,
                        Origin_Address__c,
                        Origin_Address__r.City__c,
                        Origin_Address__r.Country_Code__c,
                        Origin_Address__r.Postal_Code__c,
                        Origin_Address__r.State_Province__c,
                        Origin_Address__r.Street__c,
                        Sales_Tax_Calculation_Mode__c,
                        Sales_Tax_GL_Account__c,
                        Sales_Tax_Product__c,
                        Tax_Settings_Method__c,
                        Tax_Rounding_Threshold__c
                FROM Tax_Settings__c
                WHERE Id =: ids AND Tax_Settings_Method__c =: methods
        ];
    }

    public static List<Tax_Settings__c> getTaxSettingsByIds(Set<Id> ids) {
        return [
                SELECT Id,
                    AvaTax_License__c,
                    AvaTax_License__r.Active_AvaTax_Endpoint__c,
                    AvaTax_License__r.AvaTax_Account_ID__c,
                    AvaTax_License__r.AvaTax_License_Key__c,
                    Origin_Address__c,
                    Origin_Address__r.City__c,
                    Origin_Address__r.Country_Code__c,
                    Origin_Address__r.Postal_Code__c,
                    Origin_Address__r.State_Province__c,
                    Origin_Address__r.Street__c,
                    Sales_Tax_Calculation_Mode__c,
                    Sales_Tax_GL_Account__c,
                    Sales_Tax_Product__c,
                    Tax_Settings_Method__c,
                    Tax_Rounding_Threshold__c
                FROM Tax_Settings__c
                WHERE Id =: ids
        ];
    }

    public static List<Ledger__c> getLedgerByType(Set<String> types) {
        return getLedgerByType(types, new List<String>());
    }

    public static List<Ledger__c> getLedgerByType(Set<String> types, List<String> conditions) {

        List<String> fields = new List<String>{
            'Id',
            'Name',
            PACKAGE_QUALIFIER + 'Type__c',
            PACKAGE_QUALIFIER + 'Is_Shadow__c',
            PACKAGE_QUALIFIER + 'Billing_Activity_Statement_Format__c',
            PACKAGE_QUALIFIER + 'Billing_Outstanding_Statement_Format__c',
            PACKAGE_QUALIFIER + 'Default_Bank_Account__c',
            PACKAGE_QUALIFIER + 'Default_Billing_Format__c',
            PACKAGE_QUALIFIER + 'Default_Purchase_Order_Format__c',
            PACKAGE_QUALIFIER + 'Default_Packing_Slip_Format__c',
            PACKAGE_QUALIFIER + 'Financial_Reporter_Settings__c',
            PACKAGE_QUALIFIER + 'Consolidation_Ledger_ID__c',
            PACKAGE_QUALIFIER + 'Tax_Settings__c',
            PACKAGE_QUALIFIER + 'Tax_Settings__r.' + PACKAGE_QUALIFIER + 'Tax_Settings_Method__c',
            PACKAGE_QUALIFIER + 'Sales_Tax_Company_Code__c',
            PACKAGE_QUALIFIER + 'Accounting_Method__c',
            PACKAGE_QUALIFIER + 'Related_Ledger__c',
            PACKAGE_QUALIFIER + 'Active__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('CurrencyIsoCode');
        }

        if (AccountingSettingsHandler.isAvaVATInstalled() && AccountingSettingsHandler.doAvaVATFieldsExist()) {
            fields.add(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER + 'Company_Code__c');
            fields.add(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER + 'VAT_Country__c');
        }

        conditions.add(PACKAGE_QUALIFIER + 'Type__c IN :types');
        String theQuery =
            'SELECT ' + String.join(fields, ',') +
                ' FROM ' + PACKAGE_QUALIFIER + 'Ledger__c ' +
                ' WHERE ' + String.join(conditions, ' AND ') +
                ' ORDER BY ' + PACKAGE_QUALIFIER + 'Type__c DESC, Name ASC';

        return (List<Ledger__c>) Database.query(theQuery);
    }

    public static List<GL_Account_Mapping__c> getGLAccountMappings(Boolean onlyActive) {
        String theQuery =
            'SELECT Id, ' +
                PACKAGE_QUALIFIER + 'External_Id__c, ' +
                PACKAGE_QUALIFIER + 'GL_Account__c, ' +
                PACKAGE_QUALIFIER + 'Ledger__c, ' +
                PACKAGE_QUALIFIER + 'Inactive__c, ' +
                PACKAGE_QUALIFIER + 'Available_Balance__c, ' +
                PACKAGE_QUALIFIER + 'Current_Balance__c, ' +
                PACKAGE_QUALIFIER + 'Financial_Institution__c, ' +
                PACKAGE_QUALIFIER + 'Financial_Institution_Id__c, ' +
                PACKAGE_QUALIFIER + 'Financial_Institution_Id_Actual__c, ' +
                PACKAGE_QUALIFIER + 'Last_Refreshed__c, ' +
                PACKAGE_QUALIFIER + 'Account_Name__c, ' +
                PACKAGE_QUALIFIER + 'FIA_Status__c, ' + 
                PACKAGE_QUALIFIER + 'Initial_Start_Date__c, ' + 
                PACKAGE_QUALIFIER + 'Source__c, ' + 
                'createdDate '  + 
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? ',CurrencyIsoCode ' : '') +
                'FROM ' + PACKAGE_QUALIFIER + 'GL_Account_Mapping__c ' +
                (onlyActive ? 'WHERE ' + PACKAGE_QUALIFIER + 'Inactive__c = false ' : '') +
                'LIMIT 50000';

        return (List<GL_Account_Mapping__c>) Database.query(theQuery);
    }

    public static List<GL_Account_Mapping__c> getGLAccountMappingsByLastRefreshedDate(DateTime thresholdDateTime) {
        return [SELECT  Id,
                        External_Id__c,
                        Last_Refreshed__c,
                        Initial_Start_Date__c,
                        Source__c
                FROM GL_Account_Mapping__c
                WHERE Inactive__c = FALSE
                AND (Source__c != :BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT)
                AND (Last_Refreshed__c < :thresholdDateTime OR Last_Refreshed__c = NULL)
                LIMIT 10000
                ];
    }

    
    public static List<GL_Account_Mapping__c> getGLAccountMappingsBySourceLastRefreshedDate(Datetime thresholdDateTime, String source) {
        return [SELECT  Id,
                        External_Id__c,
                        Last_Refreshed__c,
                        Initial_Start_Date__c,
                        Source__c,
                        Financial_Institution__c,
                        Financial_Institution_Id__c,
                        Financial_Institution_Id_Actual__c,
                        CreatedDate
                FROM GL_Account_Mapping__c
                WHERE Inactive__c = FALSE
                AND (Source__c = :source)
                AND (Last_Refreshed__c < :thresholdDateTime OR Last_Refreshed__c = NULL)
                LIMIT 10000
                ];
    }

    public static List<GL_Account_Mapping__c> getGLAccountMappingsByExternalIds(Set<String> externalIds) {
        return [
            SELECT  Id,
                External_Id__c,
                GL_Account__c,
                Last_Refreshed__c,
                Current_Balance__c,
                Available_Balance__c,
                Ledger__c,
                Financial_Institution_Id__c,
                FIA_Status__c,
                Source__c,
                Initial_Start_Date__c
            FROM GL_Account_Mapping__c
            WHERE External_Id__c IN :externalIds
            LIMIT 10000
        ];
    }

    public static List<GL_Account_Mapping__c> getGLAccountMappingsByExternalIdsAndFIAIds(Set<String> externalIds, set<String> fiaIds) {
        Set<GL_Account_Mapping__c> returnSet = new Set<GL_Account_Mapping__c>();
        returnSet.addAll(getGLAccountMappingsByExternalIds(externalIds));
        returnSet.addAll(getGLAccountMappingsByFinancialInstitutionIds(fiaIds));
        List<GL_Account_Mapping__c> returnList = new List<GL_Account_Mapping__c>();
        returnList.addAll(returnSet);
        return returnList;
    }

    public static List<GL_Account_Mapping__c> getGLAccountMappingsByFinancialInstitutionIds(Set<String> fiaIds) {
        return [
            SELECT  Id,
                External_Id__c,
                GL_Account__c,
                Last_Refreshed__c,
                Current_Balance__c,
                Available_Balance__c,
                Ledger__c,
                Financial_Institution_Id__c,
                FIA_Status__c,
                Source__c,
                Initial_Start_Date__c
            FROM GL_Account_Mapping__c
            WHERE Financial_Institution_Id__c IN :fiaIds
            LIMIT 10000
        ];
    }

    public static List<AggregateResult> getRelatedObjectCountByApiNameAndLookupName(Set<Id> ids, String objectApiNameWithPQ, String lookupName) {
        String packageQualifier = objectApiNameWithPQ.startsWith(ERP_PACKAGE_QUALIFIER) && !String.isEmpty(PACKAGE_QUALIFIER)
            ? ERP_PACKAGE_QUALIFIER : PACKAGE_QUALIFIER;

        String lookupFieldApiName;
        if (String.isNotBlank(packageQualifier) && !lookupName.containsIgnoreCase(packageQualifier)) {
            lookupFieldApiName = packageQualifier + lookupName;
        }
        else if (String.isBlank(packageQualifier) || (String.isNotBlank(packageQualifier) && lookupName.containsIgnoreCase(packageQualifier))) {
            lookupFieldApiName = lookupName;
        }

        String queryString = 'SELECT ' + lookupFieldApiName + ' Id, COUNT(Id) itemCount '
            + 'FROM ' + objectApiNameWithPQ + ' WHERE '
            + lookupFieldApiName + ' IN :ids '
            + 'GROUP BY ' + lookupFieldApiName;

        return (List<AggregateResult>) Database.query(queryString);
    }

    public static List<AggregateResult> getRelatedObjectCountByApiNameAndLookupNames(Set<Id> ids, String objectApiNameWithPQ, List<String> lookupNames) {
        String packageQualifier = objectApiNameWithPQ.startsWith(ERP_PACKAGE_QUALIFIER) && !String.isEmpty(PACKAGE_QUALIFIER)
            ? ERP_PACKAGE_QUALIFIER : PACKAGE_QUALIFIER;

        String fieldsWithAlias = '';
        String whereClause = '';
        String groupBy = '';
        for (String lookupName : lookupNames) {
            fieldsWithAlias += packageQualifier + lookupName + ' ' + lookupName.removeEnd('__c') + ', ';
            whereClause += '(' + packageQualifier + lookupName + ' IN :ids) OR ';
            groupBy += packageQualifier + lookupName + ', ';
        }
        whereClause = whereClause.removeEnd('OR ');
        groupBy = groupBy.removeEnd(', ');

        String queryString =
            'SELECT ' + fieldsWithAlias + ' COUNT(Id) itemCount '
            + 'FROM ' + objectApiNameWithPQ
            + ' WHERE ' + whereClause
            + ' GROUP BY ' + groupBy;

        return (List<AggregateResult>) Database.query(queryString);
    }

    public static List<Journal_Entry__c> journalEntriesById(Set<Id> ids) {
        List<String> fields = new List<String>(SchemaDescribe.getDescribe(Journal_Entry__c.getSObjectType()).getFields().keySet());
        List<String> conditions = new List<String>{'Id =: ids'};
        return Database.query(String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(fields, ', '),
                PACKAGE_QUALIFIER + 'Journal_Entry__c',
                ' WHERE ' + String.join(conditions, ' AND ')
        }));
    }

    public static Set<Id> parentIdsWithLines(String lineSObjectName, String refToParent, Set<Id> sourceIds) {
        return countLineResultsByParentIds(lineSObjectName, refToParent, sourceIds).keySet();
    }

    public static Map<Id, AggregateResult> countLineResultsByParentIds(String lineSObjectName, String refToParent, Set<Id> sourceIds) {
        List<AggregateResult> results = countLinesByParentIds(lineSObjectName, refToParent, sourceIds);
        Map<Id, AggregateResult> recordIdsWithLines = new Map<Id, AggregateResult>();
        for (AggregateResult result : results) {
            recordIdsWithLines.put((Id)result.get('refToParent'), result);
        }
        return recordIdsWithLines;
    }

    public static List<AggregateResult> countLinesByParentIds(String lineSObjectName, String refToParent, Set<Id> sourceIds) {
        List<String> conditions = new List<String>{refToParent + ' =: sourceIds'};
        return Database.query(String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(new List<String>{refToParent + ' refToParent', 'Count(Id) c0unt'}, ', '),
                lineSObjectName,
                ' WHERE ' + String.join(conditions, ' AND ')
                    + ' GROUP BY ' + refToParent
        }));
    }

    public static List<SObject> inProgressRecordsBySObjectType(SObjectType sObjType, SObjectField statusField, String status) {
        return Database.query(String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(new List<String>{ 'Id' }, ','),
                String.valueOf(sObjType),
                'WHERE ' + String.valueOf(statusField) + ' =: status' +
                ' LIMIT 1'
        }));
    }

    public static List<SObject> recordsByConditions(SObjectType sObjType, List<String> fields, String condition, List<Object> args) {
        Object arg0 = args.size() > 0 ? args[0] : null;
        Object arg1 = args.size() > 1 ? args[1] : null;
        Object arg2 = args.size() > 2 ? args[2] : null;
        List<SObject> records = Database.query(String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(fields, ','),
                String.valueOf(sObjType),
                String.isNotBlank(condition) ? 'WHERE ' + condition : ''
        }));
        return records;
    }

    public static List<Journal_Entry__c> getJournalEntryById(Set<Id> ids) {
        List<Journal_Entry__c> result = [
            SELECT  Id,
                    Name,
                    Ledger__c,
                    Journal_Date__c,
                    Status__c,
                    (SELECT Id, Name FROM Journal_Entry_Lines__r LIMIT 1)
            FROM Journal_Entry__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Recurring_Journal_Entry__c> getRecurringJournalEntryById(Set<Id> ids) {
        List<Recurring_Journal_Entry__c> result = [
            SELECT  Id,
                Name,
                Ledger__c,
                Status__c,
            (SELECT Id, Name FROM Recurring_Journal_Entry_Lines__r LIMIT 1)
            FROM Recurring_Journal_Entry__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Journal_Entry__c> getJournalEntryByIdForUpdate(Set<Id> ids) {
        List<Journal_Entry__c> result = [
            SELECT  Id, Name, Status__c
            FROM Journal_Entry__c
            WHERE Id IN :ids FOR UPDATE
        ];
        return result;
    }

    public static List<Journal_Entry__c> getJournalEntryByReference(Set<String> merchantBatchIds) {
        List<Journal_Entry__c> result = [
            SELECT Id, Reference__c, Ledger__c,
            (SELECT Id, GL_Account__c, Credit__c, Debit__c, Journal_Entry__c FROM Journal_Entry_Lines__r)
            FROM Journal_Entry__c 
            WHERE Reference__c 
            IN : merchantBatchIds
        ];
        return result;
    }

    public static List<Journal_Entry__c> getJournalEntryByName(List<String> jeNames) {
        List<Journal_Entry__c> result = [
            SELECT  Id, Name
            FROM Journal_Entry__c
            WHERE Name IN :jeNames
        ];
        return result;
    }

    public static List<Journal_Entry_Line__c> getJournalEntryLineById(Set<Id> ids) {
        List<Journal_Entry_Line__c> result = [
            SELECT  Id,
                    Name,
                    Date__c,
                    Journal_Entry__c,
                    Journal_Entry__r.Journal_Date__c,
                    Journal_Entry__r.Accounting_Period__c,
                    Journal_Entry__r.Ledger__c,
                    Credit__c,
                    Debit__c,
                    Amount__c,
                    Bank_Id__c,
                    GL_Account__c,
                    Cash_Flow_Category__c,
                    Account__c,
                    Project__c,
                    Project_Task__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Bank_Transaction__c,
                    Description__c,
                    Bank_Disbursement__c,
                    Bank_Disbursement__r.Name,
                    Bank_Deposit__c,
                    Bank_Deposit__r.Name
            FROM Journal_Entry_Line__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Journal_Entry_Line__c> journalEntryLinesByHeaderIds(Set<Id> genericIdSet) {
        return (List<Journal_Entry_Line__c>)Database.query(journalEntryLinesByHeaderIdsQuery());
    }

    public static Database.QueryLocator billingLinesByHeaderIdsQuery(Set<String> billingLineFields, Set<Id> genericIdSet){
        List<String> conditions = new List<String>{PACKAGE_QUALIFIER + 'Billing__c =: genericIdSet'};
        return Database.getQueryLocator(
            String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(billingLineFields, ', '),
                PACKAGE_QUALIFIER + 'Billing_Line__c',
                ' WHERE ' + String.join(conditions, ' AND ')
        })
        );
    }

    public static String journalEntryLinesByHeaderIdsQuery() {
        List<String> fields = new List<String>(SchemaDescribe.getDescribe(Journal_Entry_Line__c.getSObjectType()).getFields().keySet());
        List<String> conditions = new List<String>{PACKAGE_QUALIFIER + 'Journal_Entry__c =: genericIdSet'};
        return String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(fields, ', '),
                PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
                ' WHERE ' + String.join(conditions, ' AND ')
        });
    }

    public static List<Recurring_Journal_Entry_Line__c> getRecurringJournalEntryLineById(Set<Id> ids) {
        List<Recurring_Journal_Entry_Line__c> result = [
            SELECT  Id,
                Name,
                Recurring_Journal_Entry__c,
                Recurring_Journal_Entry__r.Ledger__c,
                Credit__c,
                Debit__c,
                GL_Account__c,
                Cash_Flow_Category__c,
                Account__c,
                Project__c,
                Project_Task__c,
                GL_Account_Variable_1__c,
                GL_Account_Variable_2__c,
                GL_Account_Variable_3__c,
                GL_Account_Variable_4__c,
                Description__c
            FROM Recurring_Journal_Entry_Line__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Journal_Entry_Line__c> getJournalEntryLineLinkedWithBankTransactionByHeaderId(Set<Id> ids) {
        List<Journal_Entry_Line__c> result = [
            SELECT Id, Bank_Transaction__c
            FROM Journal_Entry_Line__c
            WHERE Journal_Entry__c IN :ids
            AND Bank_Transaction__c != NULL
        ];
        return result;
    }

    public static List<Opportunity> getOpportunityById(Set<Id> ids) {
        List<String> queryFields = new List<String>{
                'Id',
                'AccountId',
                'Account.GL_Account_Variable_1__c',
                'Account.GL_Account_Variable_2__c',
                'Account.GL_Account_Variable_3__c',
                'Account.GL_Account_Variable_4__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<Opportunity>) Database.query(theQuery.toSOQL());
    }

    public static Boolean isDiscountIncludedInOpportunityLineItems(List<Opportunity> opportunities) {
        return isDiscountIncludedInOpportunityLineItems(new Map<Id, Opportunity>(opportunities).keySet());
    }

    public static Boolean isDiscountIncludedInOpportunityLineItems(Set<Id> opportunityIds) {
        Integer discountedLines = [
            SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId IN :opportunityIds AND Discount != NULL AND Discount != 0
        ];

        return discountedLines > 0;
    }

    public static Integer getProjectCountByOpportunityId(Set<Id> oppIds) {
        Integer result = [
            SELECT COUNT() FROM Project__c WHERE Opportunity__c IN :oppIds
        ];
        return result;
    }

    public static List<Project__c> getProjects() {
        return [SELECT Id, Name FROM Project__c LIMIT 50000];
    }

    public static List<Project__c> getProjectsById(Set<Id> ids) {
        return [SELECT Id, Name FROM Project__c WHERE Id IN :ids];
    }

    public static List<Project_Task__c> getProjectTasksById(Set<Id> ids) {
        return [SELECT Id, Name FROM Project_Task__c WHERE Id IN :ids];
    }

    public static Integer countRecurringBillingsByOpportunity(Id oppId) {
        return [SELECT COUNT() FROM Recurring_Billing__c WHERE Opportunity__c = :oppId];
    }

    public static List<GL_Account__c> getCashFlowCategories() {
        List<GL_Account__c> result = [
            SELECT Id, Name, Type__c, Sub_Type_1__c, Bank__c
            FROM GL_Account__c
            WHERE Type__c = 'Cash Flow'
        ];
        return result;
    }

    public static List<GL_Account__c> getCashFlowCategoriesByName(Set<String> names) {
        List<GL_Account__c> result = [
            SELECT Id, Name, Type__c, Bank__c
            FROM GL_Account__c
            WHERE Type__c = 'Cash Flow'
            AND Name IN :names
        ];
        return result;
    }

    public static List<Cash_Receipt__c> getUncategorizedCashReceipts(List<Accounting_Period__c> periods, Integer queryLimit) {
        return [
            SELECT Id
            FROM Cash_Receipt__c
            WHERE Accounting_Period__c IN :periods
                AND Status__c = 'Posted'
                AND Cash_Flow_Category__c = NULL
            LIMIT :queryLimit
        ];
    }

    public static List<Cash_Disbursement__c> getUncategorizedCashDisbursements(List<Accounting_Period__c> periods, Integer queryLimit) {
        return [
            SELECT Id
            FROM Cash_Disbursement__c
            WHERE Accounting_Period__c IN :periods
                AND Status__c = 'Posted'
                AND Cash_Flow_Category__c = NULL
            LIMIT :queryLimit
        ];
    }

    public static List<Journal_Entry_Line__c> getUncategorizedJournalEntryLines(List<Accounting_Period__c> periods, Integer queryLimit) {
        return [
            SELECT Id
            FROM Journal_Entry_Line__c
            WHERE Journal_Entry__r.Accounting_Period__c IN :periods
                AND GL_Account__r.Bank__c = TRUE
                AND Journal_Entry__r.Status__c = 'Posted'
                AND Cash_Flow_Category__c = NULL
            LIMIT :queryLimit
        ];
    }

    public static List<Scheduled_Revenue_Expense__c> getScheduledRevenueExpensesByIdForUpdate(Set<Id> ids) {
        List<Scheduled_Revenue_Expense__c> result = [
            SELECT Id, Name, Status__c
            FROM Scheduled_Revenue_Expense__c
            WHERE Id IN :ids FOR UPDATE
        ];
        return result;
    }

    public static List<AggregateResult> getScheduledRevenueExpensesAmountSum(Id parentRecordId) {
        return [
            SELECT SUM(Amount__c) amountSum
            FROM Scheduled_Revenue_Expense__c
            WHERE Account_Payable__c =: parentRecordId OR Billing__c =: parentRecordId OR Fixed_Asset__c =: parentRecordId
        ];
    }

    public static List<AggregateResult> getScheduledRevenueExpensesByRelatedObjectCount(Set<Id> ids, String fieldApiName) {
        List<String> queryFields = new List<String>{
            'COUNT(Id)'
        };

        queryFields.add(fieldApiName);

        String queryString = 'SELECT ' + String.join(queryFields,',') + ' '
                            + 'FROM Scheduled_Revenue_Expense__c WHERE ' 
                            + fieldApiName + ' IN :ids '
                            + 'GROUP BY ' + fieldApiName;

        return (List<AggregateResult>) Database.query(queryString);
    }

    public static List<Transaction_Archive__b> queryArchivedTransactionsByFinancialCubes(Set<Id> fCubeIds) {
        List<String> queryFields = new List<String>{
            'Account__c',
            'Account__r.Name',
            'Accounting_Period__c',
            'Amortization_Entry__c',
            'Amount__c',
            'AP_Disbursement__c',
            'Billing_Cash_Receipt__c',
            'Billing__c',
            'Billing_Line__c',
            'Cash_Disbursement__c',
            'Cash_Receipt__c',
            'Date__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Time_Card_Day__c',
            'Journal_Entry_Line__c',
            'Payable__c',
            'Payable_Line__c',
            'Product__c',
            'Product__r.Name',
            'Project_Task__c',
            'Project_Task__r.Name',
            'Project__c',
            'Project__r.Name',
            'Source_Name__c'
        };

        if (AccountingSettingsHandler.isERPEnabled()) {
            queryFields.add('AcctSeedERP__Inbound_Inventory_Movement__c');
            queryFields.add('AcctSeedERP__Outbound_Inventory_Movement__c');
            queryFields.add('AcctSeedERP__Sales_Order_Inventory_Movement__c');
            queryFields.add('AcctSeedERP__Purchase_Order_Inventory_Movement__c');
            queryFields.add('AcctSeedERP__Manufacturing_Inventory_Movement__c');
        }

        String queryCondition = 'Financial_Cube__c IN : fCubeIds';

        SOQLBuilder theQuery = new SOQLBuilder(Transaction_Archive__b.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(9000);

        return (List<Transaction_Archive__b>) Database.query(theQuery.toSOQL());
    }

    public static List<Accounting_Period__c> getAllAccountingPeriods() {
        List<Accounting_Period__c> accountingPeriods = [
            SELECT Id,
                   Name,
                   Status__c,
                   Start_Date__c,
                   End_Date__c,
                   Close_AP__c,
                   Close_AR__c, 
                   Source_Docs_Deleted__c
            FROM Accounting_Period__c
            ORDER BY Start_Date__c
            LIMIT 50000
        ];

        return accountingPeriods;
    }

    public static List<AggregateResult> getPeriodsGroupedByName(Set<String> names) {
        List<AggregateResult> periodsGroupedByName = [
            SELECT COUNT(Id), Name
            FROM Accounting_Period__c
            WHERE Name IN :names
            GROUP BY Name
        ];

        return periodsGroupedByName;
    }

    public static List<ListView> getListViews(Set<String> sobjectName, List<String> listViewName) {
        List<ListView> results = [
            SELECT Id, DeveloperName
            FROM ListView
            WHERE SobjectType IN :sobjectName
            AND DeveloperName IN :listViewName
        ];
        return results;
    }

    public static List<Inventory_Cost__c> getInventoryCostByProductId(Set<Id> productIds) {
        String dynamicQueryString = 'SELECT Id, Ledger__c, Product__c, Unit_Cost__c';

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            dynamicQueryString += ', CurrencyIsoCode';
        }

        dynamicQueryString += ' FROM Inventory_Cost__c WHERE Product__c IN : productIds FOR UPDATE';

        return Database.query(dynamicQueryString);
    }

    public static List<Inventory_Cost__c> getInventoryCostByProductIdAndLedgerId(Set<Id> productIds, Set<Id> ledgerIds) {

        String dynamicQueryString = 'SELECT Id, Ledger__c, Product__c, Unit_Cost__c';

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            dynamicQueryString += ', CurrencyIsoCode';
        }

        dynamicQueryString += ' FROM Inventory_Cost__c WHERE Product__c IN : productIds AND Ledger__c IN :ledgerIds';

        return Database.query(dynamicQueryString);
    }


    public static List<Inventory_Cost__c> inventoryCostForUpdate(List<Inventory_Cost__c> inventoryCostList) {
        return [SELECT Id FROM Inventory_Cost__c WHERE Id IN :inventoryCostList FOR UPDATE];
    }

    public static List<SObject> getDatedConversionRateByCurrencyISOCodesAndDates(Set<String> currencyISOCodes, Set<Date> dates) {
        List<SObject> result = new List<SObject>();
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            String dynamicQueryString = 'SELECT IsoCode, StartDate, NextStartDate, ConversionRate FROM DatedConversionRate WHERE IsoCode IN :currencyISOCodes';

            List<String> dateFilters = new List<String>();
            for (Date recordDate : dates) {
                dateFilters.add('(StartDate <= ' + String.valueOf(recordDate) + ' AND NextStartDate > ' + String.valueOf(recordDate) + ')');
            }
            if (!dateFilters.isEmpty()) {
                dynamicQueryString += ' AND (' + String.join(dateFilters, ' OR ') + ') ';
            }
            dynamicQueryString += 'ORDER BY StartDate ASC';

            result = Database.query(dynamicQueryString);
        }
        return result;
    }

    public static List<SObject> getCurrencyTypes() {
        List<SObject> result = Database.query(
            'SELECT ConversionRate, DecimalPlaces, IsActive, IsCorporate, IsoCode FROM CurrencyType LIMIT 50000'
        );
        return result;
    }

    public static List<Ledger_Custom_Settings__c> getAllLedgerCustomSettings() {
        return [SELECT Id, Ledger_Id__c FROM Ledger_Custom_Settings__c LIMIT 50000];
    }

    public static List<SObject> getInventoryBalancesByProductByLedger(Set<Id> products, Set<Id> ledgers) {
        List<SObject> result = new List<SObject>();
        if (AccountingSettingsHandler.isERPEnabled()) {
            result = Database.query(
                'SELECT Id, ' +
                    ERP_PACKAGE_QUALIFIER + 'Product__c, ' +
                    ERP_PACKAGE_QUALIFIER + 'Ledger__c ' +
                'FROM ' + ERP_PACKAGE_QUALIFIER + 'Inventory_Balance__c ' +
                'WHERE ' + ERP_PACKAGE_QUALIFIER + 'Product__c IN :products ' +
                'AND ' + ERP_PACKAGE_QUALIFIER + 'Ledger__c IN :ledgers'
            );
        }

        return result;
    }
    
    public static Map<Id,SObject> getParentISOCode(Set<Id> ids, String parentObjectName) {
        return new Map<Id,SObject>((SObject[])Database.query(
            'SELECT Id, CurrencyIsoCode FROM ' + parentObjectName + ' ' +
            'WHERE Id IN :ids')
        );
    }

    public static List<SObject> getPurchasePriceByProduct(Set<Id> ids) {
        List<SObject> result = new List<SObject>();
        if (AccountingSettingsHandler.isERPEnabled()) {
            String dynamicQuery = 'SELECT Id, ' +
                ERP_PACKAGE_QUALIFIER + 'Product__c, ' +
                ERP_PACKAGE_QUALIFIER + 'Vendor__c, ' +
                ERP_PACKAGE_QUALIFIER + 'Unit_Price__c ' +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? ', CurrencyIsoCode ' : ' ') +
                'FROM ' +
                ERP_PACKAGE_QUALIFIER + 'Purchase_Price__c ' +
                'WHERE ' +
                ERP_PACKAGE_QUALIFIER + 'Product__c IN :ids';

            result = (List<SObject>) Database.query(dynamicQuery);
        }
        return result;
    }

    public static List<SObject> getUnitPriceOfProduct(Set<Id> ids) {
        List<SObject> result = new List<SObject>();
        if (AccountingSettingsHandler.isERPEnabled()) {
            String dynamicQuery = 'SELECT Id, ' +
                    'Unit_Cost__c' +
                    (MultiCurrencyHandler.isMultiCurrencyEnabled ? ', CurrencyIsoCode ' : ' ') +
                    'FROM Product2 ' +
                    'WHERE Id IN :ids';

            result = (List<SObject>) Database.query(dynamicQuery);
        }
        return result;
    }

    public static Map<Id, Billing__c> getAutomatedEmailBillings() {
        Map<Id, Billing__c> bills = new Map<Id, Billing__c>([
            SELECT Id,
                   Billing_Contact__c,
                   Billing_Contact__r.Email,
                   Balance__c
            FROM Billing__c
            WHERE Date__c <= :System.today()
            AND Status__c = 'Posted'
            AND PDF_Email_Status__c = 'Unsent'
            AND (
                (Balance__c > 0 AND Type__c != 'Credit Memo' AND Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due Only') 
                OR (Balance__c = 0 AND Type__c != 'Credit Memo' AND Billing_Format__r.Automated_Email_Delivery2__c = 'Zero Balance Only')
                OR (Balance__c >= 0 AND Type__c != 'Credit Memo' AND Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due or Zero Balance' )
                OR ((Balance__c > 0 OR (Type__c = 'Credit Memo' AND Balance__c < 0)) AND Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due or Credit Memo Balance')
                OR (Billing_Format__r.Automated_Email_Delivery2__c = 'Always')
            )
        ]);

        return bills;
    }

    public static List<SObject> getSObjectBySObjectTypeAndFields(SObjectType sObjectType, List<SObjectField> fields, Set<Id> ids) {
        String query = '';
        for (SObjectField fieldName : fields){
            query += fieldName + ', ';
        }
        query = query.removeEnd(', ');
       return Database.query('SELECT ' + query + ' FROM ' + sObjectType + ' WHERE Id IN :ids LIMIT 50000');
    }

    public static List<Tax_Group__c> getTaxGroupByIds(Set<Id> taxGroupIds) {
        return [
            SELECT Id, Active__c, Combined_Tax_Rate__c, Tax_Type__c, Description__c, Tax_Rate_Count__c, External_Id2__c, Reverse_Charge__c, Tax_Inclusive__c
            FROM Tax_Group__c
            WHERE Id IN :taxGroupIds
        ];
    }

    public static List<Tax_Group__c> getTaxGroupWithTaxRatesByIds(Set<Id> taxGroupIds) {
        return [
            SELECT Id, Combined_Tax_Rate__c, Tax_Type__c, Description__c, Tax_Rate_Count__c, Active__c, Tax_Inclusive__c,
                    (SELECT Id, Purchase_Tax_Expense_GL_Account__c, Sales_Tax_Liability_GL_Account__c, Tax_Rate__c FROM Tax_Rates__r)
            FROM Tax_Group__c
            WHERE Id IN :taxGroupIds
        ];
    }

    public static List<Tax_Rate__c> getTaxRatesByTaxGroupIds(Set<Id> taxGroupIds) {
        return [
            SELECT Id, Tax_Group__c, Tax_Rate__c, Purchase_Tax_Expense_GL_Account__c, Sales_Tax_Liability_GL_Account__c, Description__c, Tax_Group_External_ID__c
            FROM Tax_Rate__c
            WHERE Tax_Group__c IN :taxGroupIds
        ];
    }

    public static Integer countBillingLinesByTaxGroup(Set<Id> taxGroupIds) {
        return [SELECT COUNT() FROM Billing_Line__c WHERE Tax_Group__c IN :taxGroupIds];
    }

    public static Integer countRecurringBillingLinesByTaxGroup(Set<Id> taxGroupIds) {
        return [SELECT COUNT() FROM Recurring_Billing_Line__c WHERE Tax_Group__c IN :taxGroupIds];
    }

    public static Integer countPayableLinesByTaxGroup(Set<Id> taxGroupIds) {
        return [SELECT COUNT() FROM Account_Payable_Line__c WHERE Tax_Group__c IN :taxGroupIds];
    }

    public static Integer countRecurringPayableLinesByTaxGroup(Set<Id> taxGroupIds) {
        return [SELECT COUNT() FROM Recurring_Account_Payable_Line__c WHERE Tax_Group__c IN :taxGroupIds];
    }

    public static Integer countOpportunityLineItemByTaxGroup(Set<Id> taxGroupIds) {
        return [SELECT COUNT() FROM OpportunityLineItem WHERE Tax_Group__c IN :taxGroupIds];
    }

    public static List<OrgWideEmailAddress> getOrgWideEmailAddress() {
        return [SELECT Id, Address FROM OrgWideEmailAddress LIMIT 50000];
    }

    public static List<Bank_Transaction__c> getBankTransactionsByKey(Set<String> keys) {
        return [SELECT Id, Key__c, Bank_Transaction_Id__c FROM Bank_Transaction__c WHERE Key__c IN :keys];
    }

    public static List<Bank_Transaction__c> getBankTransactionsById(Set<Id> ids) {
        return Database.query(
            'SELECT ' +
                    ((MultiCurrencyHandler.isMultiCurrencyEnabled) ? 'CurrencyIsoCode, ' : '') +
                    'Id,Name, Key__c, Bank_Transaction_Id__c, Account_Id__c, Amount__c, Base_Type__c, Date__c, Status__c, ' +
                    'GL_Account_Mapping__c, GL_Account_Mapping__r.Ledger__c, GL_Account_Mapping__r.GL_Account__c, ' +
                    'GL_Account_Mapping__r.External_Id__c, Description__c, Simple_Description__c, ' +
                    'Category__c, High_Level_Category__c, Detail_Category__c, Source__c , Type__c ' +
                'FROM Bank_Transaction__c ' +
                'WHERE Id IN :ids'
        );
    }

    public static List<Bank_Transaction__c> getPendingBankTransactionsById(Set<Id> ids) {
        return [
            SELECT Id, Status__c
            FROM Bank_Transaction__c
            WHERE Id IN :ids
            AND Status__c = :BankTransactionsHelper.BT_IN_PROCESS_STATUS
        ];
    }

    public static List<Bank_Rule__c> getBankRulesComposed(String type, Boolean isActive) {
        return [
            SELECT
                Id,
                Name,
                Active__c,
                Evaluation_Type__c,
                Priority__c,
                Source_Record_Type__c,
                Type__c,
                Description__c,
                Apply_To_All_Financial_Accounts__c,
                (SELECT
                    Id,
                    Name,
                    Bank_Rule__c,
                    Amount__c,
                    Operator__c,
                    Target_Field__c,
                    Description__c,
                    High_Level_Category__c,
                    Category__c,
                    Detail_Category__c,
                    Base_Type__c,
                    Type__c
                FROM Bank_Rule_Conditions__r),
                (SELECT
                    Id,
                    Name,
                    Bank_Rule__c,
                    Target_Field__c,
                    Value__c
                FROM Bank_Rule_Actions__r),
                (SELECT
                    Id,
                    Name,
                    Bank_Rule__c,
                    GL_Account_Mapping__c,
                    GL_Account_Mapping__r.Ledger__c,
                    GL_Account_Mapping__r.GL_Account__c,
                    GL_Account_Mapping__r.Financial_Institution__c,
                    GL_Account_Mapping__r.Financial_Institution_Id__c
                FROM Bank_Rule_GLAMs__r)
            FROM Bank_Rule__c
            WHERE Active__c = :isActive
            AND Type__c = :type
            ORDER BY Priority__c ASC
        ];
    }

    public static List<Bank_Rule__c> getBankRulesByPriority(Set<Decimal> priority) {
        return [
            SELECT
                Id,
                Priority__c,
                Type__c
            FROM Bank_Rule__c
            WHERE Priority__c IN :priority
        ];
    }

    public static List<Bank_Rule__c> getBankRulesById(Set<Id> bankRuleIds) {
        return [
            SELECT Id, Source_Record_Type__c
            FROM Bank_Rule__c
            WHERE Id IN :bankRuleIds
        ];
    }

    public static List<Bank_Rule_Action__c> getBankRuleActionsByBankRule(Set<Id> ruleIds) {
        return [
            SELECT
                Id,
                Bank_Rule__c,
                Target_Field__c
            FROM Bank_Rule_Action__c
            WHERE Bank_Rule__c IN :ruleIds
        ];
    }

    public static Integer countActiveBankRules() {
        return [
            SELECT COUNT()
            FROM Bank_Rule__c
            WHERE Active__c = TRUE
        ];
    }

    public static List<AggregateResult> getBankRulesWithGreaterThanNumActions(Set<Id> ruleIds, Integer numActions) {
        return [
            SELECT COUNT(Id) cnt, Bank_Rule__c
            FROM Bank_Rule_Action__c
            WHERE Bank_Rule__c IN :ruleIds
            GROUP BY Bank_Rule__c
            HAVING COUNT(Id) > :numActions
        ];
    }

    public static List<AggregateResult> getBankRulesWithGreaterThanNumConditions(Set<Id> ruleIds, Integer numConditions) {
        return [
            SELECT COUNT(Id) cnt, Bank_Rule__c
            FROM Bank_Rule_Condition__c
            WHERE Bank_Rule__c IN :ruleIds
            GROUP BY Bank_Rule__c
            HAVING COUNT(Id) > :numConditions
        ];
    }

    public static List<SObject> getSourceDocumentsHavingBankTransactionById(Set<Id> ids, SObjectType objType) {
        return Database.query('SELECT Id, Bank_Transaction__c FROM ' + objType + ' WHERE Id IN:ids AND Bank_Transaction__c != NULL');
    }

    /****************** 1099 CMT Queries ****************************************/

    public static List<Form_Type__mdt> getFormTypesByEffectiveYear(Integer effectiveYear) {
        String queryString = 'SELECT Id, Label, Effective_Year__c FROM Form_Type__mdt';
        if (effectiveYear != null) {
            queryString += ' WHERE Effective_Year__c <= :effectiveYear';
        }
        queryString += ' ORDER BY Effective_Year__c DESC, Label ASC';
        return database.query(queryString);
    }

    public static List<Form_Type__mdt> getFormTypesOrderByTypeYearASC(Integer effectiveYear) {
        String queryString = 'SELECT Id, Label, Effective_Year__c, Type__c FROM Form_Type__mdt';
        if (effectiveYear != null) {
            queryString += ' WHERE Effective_Year__c <= :effectiveYear';
        }
        queryString += ' ORDER BY Type__c DESC, Effective_Year__c ASC';
        return database.query(queryString);
    }

    public static List<Form_Category__mdt> getFormCategories() {
        return getFormCategories(null);
    }
    
    public static List<Form_Category__mdt> getFormCategories(String formTypeId) {
        String queryString = 'SELECT Id, Label, Sort_Order__c, Form_Type__r.Effective_Year__c, ' +
                                'Form_Type__r.Type__c, Form_Type__r.Label, Form_Type__r.Id ' + 
                                'FROM Form_Category__mdt';
        if (!String.isEmpty(formTypeId)) {
            queryString += ' WHERE Form_Type__c = :formTypeId';
        }
        queryString += ' ORDER BY Sort_Order__c ASC';
        return database.query(queryString);
    }

    public static List<Form_Category__mdt> getFormCategoryById(String formCategoryId) {
        return [SELECT Id, Label, Form_Type__r.Label, Form_Type__r.Id FROM Form_Category__mdt WHERE Id = :formCategoryId];        
    }

    public static List<Form_Type__mdt> getMaxEffectiveDateForTypeAndYear(String formType, Integer effectiveYear) {
        return [SELECT Effective_Year__c FROM Form_Type__mdt WHERE Type__c = :formType AND Effective_Year__c <= :effectiveYear ORDER BY Effective_Year__c DESC];        
    }

    public static List<Form_Type__mdt> getFormTypesById(String formTypeId) {
        return [SELECT Id, Effective_Year__c, Type__c FROM Form_Type__mdt WHERE Id = :formTypeId];        
    }

    public static List<Form_Category__mdt> getFormCategoriesByIds(Id[] formCategoryIds) {
        return [
            SELECT 
                Id
                , Form_Type__r.Id
                , Form_Type__r.Type__c
                , Form_Type__r.Effective_Year__c
            FROM Form_Category__mdt
            WHERE Id IN :formCategoryIds
        ];
    }

    /****************** GL Account Balance Queries **********************/

    public static List<Financial_Cube__c> getFinancialCubesForPeriod(Id periodId, GLAccountBalanceOption options) {
        Id glAccountId = options.glAccountId;
        Id ledgerId = options.ledgerId;
        Id glVariable1Id = options.glVariable1Id;
        Id glVariable2Id = options.glVariable2Id;
        Id glVariable3Id = options.glVariable3Id;
        Id glVariable4Id = options.glVariable4Id;
        String cubeType = 'Period';
        
        String q = 
            'SELECT Year_To_Date__c ' +
            'FROM Financial_Cube__c ' +
            'WHERE GL_Account__c = :glAccountId ' +
            'AND Ledger__c = :ledgerId ' +
            'AND Cube_Type__c = :cubeType ' +
            'AND Accounting_Period__c = :periodId ';
            q += glVariable1Id <> null ? 'AND GL_Account_Variable_1__c = :glVariable1Id ' : '';
            q += glVariable2Id <> null ? 'AND GL_Account_Variable_2__c = :glVariable2Id ' : '';
            q += glVariable3Id <> null ? 'AND GL_Account_Variable_3__c = :glVariable3Id ' : '';
            q += glVariable4Id <> null ? 'AND GL_Account_Variable_4__c = :glVariable4Id ' : '';
        
        return (List<Financial_Cube__c>) Database.query(q);
    }

    public static Integer countTransactionsSince(Date startDate, GLAccountBalanceOption options) {
        Id glAccountId = options.glAccountId;
        Id ledgerId = options.ledgerId;
        Id glVariable1Id = options.glVariable1Id;
        Id glVariable2Id = options.glVariable2Id;
        Id glVariable3Id = options.glVariable3Id;
        Id glVariable4Id = options.glVariable4Id;
        Date inquiryDate = options.inquiryDate;
        
        String q = 
            'SELECT COUNT() ' +
            'FROM Transaction__c ' +
            'WHERE GL_Account__c = :glAccountId ' +
            'AND Ledger__c = :ledgerId ' +
            'AND Date__c <= :inquiryDate ' +
            'AND Accounting_Period__r.Start_Date__c >= :startDate ';
            q += glVariable1Id <> null ? 'AND GL_Account_Variable_1__c = :glVariable1Id ' : '';
            q += glVariable2Id <> null ? 'AND GL_Account_Variable_2__c = :glVariable2Id ' : '';
            q += glVariable3Id <> null ? 'AND GL_Account_Variable_3__c = :glVariable3Id ' : '';
            q += glVariable4Id <> null ? 'AND GL_Account_Variable_4__c = :glVariable4Id ' : '';
        
        return Database.countQuery(q);
    }

    public static Decimal sumTransactionsSince(Date startDate, GLAccountBalanceOption options) {
        Id glAccountId = options.glAccountId;
        Id ledgerId = options.ledgerId;
        Id glVariable1Id = options.glVariable1Id;
        Id glVariable2Id = options.glVariable2Id;
        Id glVariable3Id = options.glVariable3Id;
        Id glVariable4Id = options.glVariable4Id;
        Date inquiryDate = options.inquiryDate;

        String q = 
            'SELECT SUM(Amount__c) amt ' +
            'FROM Transaction__c ' +
            'WHERE GL_Account__c = :glAccountId ' +
            'AND Ledger__c = :ledgerId ' +
            'AND Date__c <= :inquiryDate ' +
            'AND Accounting_Period__r.Start_Date__c >= :startDate ';
            q += glVariable1Id <> null ? 'AND GL_Account_Variable_1__c = :glVariable1Id ' : '';
            q += glVariable2Id <> null ? 'AND GL_Account_Variable_2__c = :glVariable2Id ' : '';
            q += glVariable3Id <> null ? 'AND GL_Account_Variable_3__c = :glVariable3Id ' : '';
            q += glVariable4Id <> null ? 'AND GL_Account_Variable_4__c = :glVariable4Id ' : '';

        AggregateResult result = (AggregateResult) Database.query(q);

        Decimal sum = result.get('amt') <> null ? (Decimal) result.get('amt') : (Decimal) 0.0;
        return MultiCurrencyHandler.getNormalizedBalance(sum, LedgerHandler.getLedgerCurrency(options.ledgerId));
    }

    public static Database.QueryLocator getTransactionsQueryLocatorForGLAccountBalance(Date startDate, GLAccountBalanceOption options) {
        Id glAccountId = options.glAccountId;
        Id ledgerId = options.ledgerId;
        Id glVariable1Id = options.glVariable1Id;
        Id glVariable2Id = options.glVariable2Id;
        Id glVariable3Id = options.glVariable3Id;
        Id glVariable4Id = options.glVariable4Id;
        Date inquiryDate = options.inquiryDate;

        String q = 
            'SELECT Amount__c ' +
            'FROM Transaction__c ' +
            'WHERE GL_Account__c = :glAccountId ' +
            'AND Ledger__c = :ledgerId ' +
            'AND Date__c <= :inquiryDate ' +
            'AND Accounting_Period__r.Start_Date__c >= :startDate ';
            q += glVariable1Id <> null ? 'AND GL_Account_Variable_1__c = :glVariable1Id ' : '';
            q += glVariable2Id <> null ? 'AND GL_Account_Variable_2__c = :glVariable2Id ' : '';
            q += glVariable3Id <> null ? 'AND GL_Account_Variable_3__c = :glVariable3Id ' : '';
            q += glVariable4Id <> null ? 'AND GL_Account_Variable_4__c = :glVariable4Id ' : '';

        return Database.getQueryLocator(q);
    }

    public static Database.QueryLocator getFinCubesQueryLocatorForGLAccountBalance(Id periodId, GLAccountBalanceOption options) {
        Id glAccountId = options.glAccountId;
        Id ledgerId = options.ledgerId;
        Id glVariable1Id = options.glVariable1Id;
        Id glVariable2Id = options.glVariable2Id;
        Id glVariable3Id = options.glVariable3Id;
        Id glVariable4Id = options.glVariable4Id;
        String cubeType = 'Period';

        String q =
            'SELECT Year_To_Date__c ' +
                'FROM Financial_Cube__c ' +
                'WHERE GL_Account__c = :glAccountId ' +
                'AND Ledger__c = :ledgerId ' +
                'AND Cube_Type__c = :cubeType ' +
                'AND Accounting_Period__c = :periodId ';
        q += glVariable1Id <> null ? 'AND GL_Account_Variable_1__c = :glVariable1Id ' : '';
        q += glVariable2Id <> null ? 'AND GL_Account_Variable_2__c = :glVariable2Id ' : '';
        q += glVariable3Id <> null ? 'AND GL_Account_Variable_3__c = :glVariable3Id ' : '';
        q += glVariable4Id <> null ? 'AND GL_Account_Variable_4__c = :glVariable4Id ' : '';

        return Database.getQueryLocator(q);
    }

    public static Integer countActiveGLAVs() {
        List<String> glavTypes = new List<String>{
            AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_1,
            AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_2,
            AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_3,
            AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_4
        };

        return [
            SELECT COUNT()
            FROM Accounting_Variable__c
            WHERE Type__c IN :glavTypes
            AND Active__c = TRUE
        ];
    }

    public static List<Financial_Reporter_Settings__c> getFinancialReporterSettingsById(Set<Id> ids) {
        return [
            SELECT Id, Name, Column_Header_Variant__c, Company_Name__c, Rounding__c, Expand_Report_Rows__c
            FROM Financial_Reporter_Settings__c
            WHERE Id IN :ids
        ];
    }

    public static List<Ledger_Hierarchy__c> getLedgerHierarchies() {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Last_Period__c',
            'Last_Period__r.Name',
            'Last_Run__c',
            'Generated_By__c',
            'Generated_By__r.Name',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Notes__c',
            'Parent_Ledger_Hierarchy__c',
            'Root_Node_ID__c',
            'Hierarchy_Status__c',
            'Sort_Order__c',
            'Hierarchy_Type__c',
            'LastModifiedBy.Name'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('Ledger__r.CurrencyIsoCode');
        }

        String q = String.format('SELECT {0} FROM Ledger_Hierarchy__c', new String[]{ String.join(fields, ',') });

        return (List<Ledger_Hierarchy__c>) Database.query(q);
    }

    public static List<Ledger__c> getCLedgersWithFinancialCubesByIds(Set<Id> consolidationLedgerIds) {
        return [
                SELECT Id, (
                        SELECT Id
                        FROM Financial_Cubes__r
                        WHERE Accounting_Period__r.Status__c IN (:AccountingPeriodActions.CLOSED_STATUS, :AccountingPeriodActions.ARCHIVED_STATUS)
                        LIMIT 1
                )
                FROM Ledger__c
                WHERE Id IN :consolidationLedgerIds
                AND Type__c IN (:LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL, :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET)
        ];
    }

    public static List<Ledger__c> getLedgersWithLedgerHierarchyByIds(Set<Id> rootNodeIds, Set<Id> ledgerIds) {
        List<String> LEDGER_TYPE_CONSOLIDATIONS = new List<String>{
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET
        };
        List<String> subFields = new List<String>{
            'Id',
            'Root_Node_ID__c'
        };
        String subQuery = String.format(
            'SELECT {0} ' +
                'FROM Ledger_Hierarchy__r ' +
                'WHERE Ledger__r.Type__c IN :LEDGER_TYPE_CONSOLIDATIONS OR Root_Node_ID__c IN :rootNodeIds',
            new List<String>{String.join(subFields, ',')}
        );
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Accounting_Method__c',
            '(' + subQuery + ')'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('CurrencyIsoCode');
        }
        return Database.query(String.format('SELECT {0} FROM Ledger__c WHERE Id IN :ledgerIds', new List<String>{
                String.join(fields, ',')
        }));
    }

    public static List<Ledger_Hierarchy__c> getLedgerHierarchiesByIds(Set<Id> ledgerIds) {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Notes__c',
            'Root_Node_ID__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Accounting_Method__c',
            'Hierarchy_Type__c',
            'Hierarchy_Status__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fields.add('Ledger__r.CurrencyIsoCode');
            fields.add('CurrencyIsoCode');
        }
        return Database.query(
            String.format('SELECT {0} FROM Ledger_Hierarchy__c WHERE Id IN :ledgerIds', new List<String>{
                String.join(fields, ',')
            })
        );
    }

    public static List<AggregateResult> getCountOfClosedCFCubes(Set<Id> ledgerIds) {
        return [
            SELECT COUNT(Id) c0unt, Ledger__c cLedgerId
            FROM Financial_Cube__c
            WHERE Ledger__c = :ledgerIds
            AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
            AND Accounting_Period__r.Status__c = :AccountingPeriodActions.CONSIDERED_CLOSED_STATUSES
            GROUP BY Ledger__c
            HAVING COUNT(Id) > 0
            LIMIT 2000
        ];
    }

    public static Map<Id, AggregateResult> getLedgerHierarchiesMaxSortOrder(Set<Id> ids) {
        return new Map<Id, AggregateResult>([
            SELECT Parent_Ledger_Hierarchy__c Id, MAX(Sort_Order__c) MAX
            FROM Ledger_Hierarchy__c
            WHERE Parent_Ledger_Hierarchy__c != NULL
            AND Parent_Ledger_Hierarchy__c IN :ids
            GROUP BY Parent_Ledger_Hierarchy__c
        ]);
    }

    public static List<Ledger_Hierarchy__c> getParentLedgerHierarchiesMaxSortOrder() {
        return [
            SELECT Sort_Order__c
            FROM Ledger_Hierarchy__c
            WHERE Parent_Ledger_Hierarchy__c = NULL
            ORDER BY Sort_Order__c DESC LIMIT 2
        ];
    }
    
    public static List<AggregateResult> getCountOfCLHierarchyChildren(Set<Id> cLedgerHierarchyIds) {
        return [
                SELECT COUNT(Id) recCount, Parent_Ledger_Hierarchy__c hierarchyId
                FROM Ledger_Hierarchy__c
                WHERE Parent_Ledger_Hierarchy__c = :cLedgerHierarchyIds
                AND Parent_Ledger_Hierarchy__r.Ledger__r.Type__c
                    IN (:LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                        :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET)
                AND Ledger__r.Type__c
                    IN (:LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                        :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET,
                        :LedgerActions.LEDGER_TYPE_BUDGET,
                        :LedgerActions.LEDGER_TYPE_TRANSACTIONAL)
                GROUP BY Parent_Ledger_Hierarchy__c
                HAVING COUNT(Id) > 0
                LIMIT 2000
        ];
    }

   
    public static List<Ledger_Hierarchy__c> getEliminationsLedgerHierarchies(Set<Id> cLedgerHierarchyIds) {
        return [
            SELECT Id
            FROM Ledger_Hierarchy__c
            WHERE Parent_Ledger_Hierarchy__c = :cLedgerHierarchyIds
            AND Ledger__r.Type__c IN (:LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL, :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET)
            AND Parent_Ledger_Hierarchy__r.Ledger__r.Type__c IN (:LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL, :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET)
        ];
    }

    public static List<Exchange_Rate__c> getExchangeRateTableByDateAndTypeAndCurrency(
        Date startDate,
        Date endDate,
        Set<String> types,
        Set<String> currencyCodes
    ) {
        return [
            SELECT Id,
                Exchange_Rate__c,
                Rate_Type__c,
                Effective_From__c,
                Effective_To__c,
                From_Currency_Code__c,
                To_Currency_Code__c,
                Next_Exchange_Rate__c
            FROM Exchange_Rate__c
            WHERE ((Effective_From__c <= :endDate AND Effective_To__c = NULL)
            OR (Effective_To__c != NULL AND Effective_To__c >= :startDate AND Effective_From__c <= :endDate))
            AND Rate_Type__c IN :types
            AND (From_Currency_Code__c IN :currencyCodes OR To_Currency_Code__c IN :currencyCodes)
        ];
    }

    public static List<Exchange_Rate__c> getLastExchangeRateTableByTypeAndCurrency(Set<String> types, Set<String> currencyCodes) {
        return [
            SELECT
                Id,
                Exchange_Rate__c,
                Rate_Type__c,
                Effective_From__c,
                Effective_To__c,
                From_Currency_Code__c,
                To_Currency_Code__c,
                Next_Exchange_Rate__c
            FROM Exchange_Rate__c
            WHERE Rate_Type__c IN :types
            AND (From_Currency_Code__c IN :currencyCodes OR To_Currency_Code__c IN :currencyCodes)
            AND Effective_To__c = NULL
        ];
    }

    public static List<Exchange_Rate__c> getFirstExchangeRateTableByTypeAndCurrency(Set<String> types, Set<String> currencyCodes) {
        return [
            SELECT
                Id,
                Exchange_Rate__c,
                Rate_Type__c,
                Effective_From__c,
                Effective_To__c,
                From_Currency_Code__c,
                To_Currency_Code__c,
                Next_Exchange_Rate__c
            FROM Exchange_Rate__c
            WHERE Rate_Type__c IN :types
            AND (From_Currency_Code__c IN :currencyCodes OR To_Currency_Code__c IN :currencyCodes)
            ORDER BY Effective_From__c ASC
        ];
    }

    public static List<Exchange_Rate__c> getExchangeRateTableByNextTableId(Set<Id> Ids) {
        return [
            SELECT Id,
                Exchange_Rate__c,
                Rate_Type__c,
                Effective_From__c,
                Effective_To__c,
                From_Currency_Code__c,
                To_Currency_Code__c,
                Next_Exchange_Rate__c
            FROM Exchange_Rate__c
            WHERE Next_Exchange_Rate__c IN :Ids
        ];
    }

    public static Integer getTransactionalLedgerCount() {
        return [
            SELECT COUNT()
            FROM Ledger__c
            WHERE Type__c = :LedgerActions.LEDGER_TYPE_TRANSACTIONAL
        ];
    }

    public static String getCurrencyISOCodeById(Id recordId) {
        String query = String.format('SELECT {0} FROM {1} {2}', new List<String>{
                String.join(new List<String>{'CurrencyISOCode'}, ','),
                recordId.getSobjectType().getDescribe().name,
                'WHERE Id =: recordId'
        });
        List<SObject> records = Database.query(query);
        return !records.isEmpty() && records[0].get('CurrencyISOCode') != null ? (String)records[0].get('CurrencyISOCode') : null;
    }

    public static Map<Id, SObject> fetchPayableByIdsWithTaxSettings(SObjectType objectType, Set<Id> ids) {
        SOQLBuilder theQuery = new SOQLBuilder(objectType);
        theQuery
                .setEnforceFLS(false)
                .selectFields(new List<String>{'Ledger__r.Tax_Settings__c'})
                .setCondition('Id =: ids');

        return new Map<Id, SObject>(Database.query(theQuery.toSOQL()));
    }

    public static List<AggregateResult> getMaxCheckNumberForCashReceipts(Set<Id> bankAccountIds) {
        return [
            SELECT MAX(Check_Number__c) maxCheckNumber, Bank_Account__c bankAccountId
            FROM Cash_Receipt__c
            WHERE Bank_Account__c IN :bankAccountIds
            AND Payment_Type__c = 'Check'
            AND Check_Number__c != NULL
            GROUP BY Bank_Account__c
        ];
    }

    public static Decimal getLastCheckNumberForCashReceipts(Id bankAccountId) {
        Decimal highstChkNum = 0;

        List<Cash_Receipt__c> result = [
            SELECT Check_Number__c
            FROM Cash_Receipt__c
            WHERE Bank_Account__c = :bankAccountId
            AND Payment_Type__c = 'Check'
            AND Check_Number__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];
        
        for(Cash_Receipt__c cr : result){
            if(highstChkNum < cr.Check_Number__c){
                highstChkNum = cr.Check_Number__c;
            }
        }
        return highstChkNum;
    }

    public static Integer getCountCheckNumberForCashReceipts() {
        return [
            SELECT COUNT()
            FROM Cash_Receipt__c
            WHERE Payment_Type__c = 'Check'
            AND Check_Number__c != NULL
            LIMIT 50002
        ];
    }

    public static List<AggregateResult> getMaxCheckNumberForCashDisbursements(Set<Id> bankAccountIds) {
        return [
            SELECT MAX(Check_Number__c) maxCheckNumber, Bank_Account__c bankAccountId
            FROM Cash_Disbursement__c
            WHERE Bank_Account__c IN :bankAccountIds
            AND Check_Number__c != NULL
            GROUP BY Bank_Account__c
        ];
    }

    public static List<AggregateResult> getPaymentProcessorsHistoricalVolume(String processorType) {
        return [
            SELECT DAY_ONLY(CreatedDate) day, COUNT(Id) cnt, Cash_Receipt__r.Payment_Processor__c
            FROM Payment_Activity__c
            WHERE CreatedDate >= LAST_N_DAYS:30
            AND Cash_Receipt__r.Payment_Processor__r.Type__c = :processorType
            GROUP BY DAY_ONLY(CreatedDate), Cash_Receipt__r.Payment_Processor__c
            ORDER BY COUNT(Id) DESC
        ];
    }

    public static List<Payment_Processor__c> getActivePaymentProcessorsByType(String processorType) {
        return [
            SELECT Id, Last_Sync__c
            FROM Payment_Processor__c 
            WHERE Active__c = TRUE 
            AND Type__c = :processorType
        ];
    }

    public static List<Payment_Processor__c> getActivePaymentProcessorsWithErrors() {
        return [
            SELECT Id
            FROM Payment_Processor__c 
            WHERE Active__c = TRUE 
            AND Id IN (SELECT Payment_Processor__c FROM Transaction_Import_Error__c)
        ];
    }

    public static List<Payment_Processor__c> getPaymentProcessorsById(Set<Id> paymentProcessorIds) {
        return [
            SELECT
                Active__c,
                Connected_Account_Token__c,
                Id,
                Name,
                Test_Mode__c,
                Type__c,
                External_Key__c,    
                PaymentSite_URL__c,
                Last_Sync__c,
                Default_Ledger__c,
                Enable_PaymentSITE_Partial_Payment__c,
                Merchant_GL_Account__c,
                Merchant_Fees_GL_Account__c,
                Bank_GL_Account__c,
                Enable_Convenience_Fees__c,
                Credit_Card_Convenience_Fee_Type__c,
                Convenience_Fees_GL_Account__c,
                Convenience_Fee_Mapping__c,
                Original_Amount_Mapping__c,
                CC_Flat_Fee__c,
                CC_Percent__c,
                ACH_Convenience_Fee_Type__c,
                ACH_Flat_Fee__c,
                ACH_Percent__c
            FROM Payment_Processor__c
            WHERE Id IN :paymentProcessorIds
        ];
    }

    public static Payment_Processor__c getPaymentProcessorById(Id paymentProcessorId) {
        List<Payment_Processor__c> p = DomainUtils.getPaymentProcessorsById(new Set<Id>{ paymentProcessorId });
        return p == null || p.isEmpty() ? null : p.get(0);
    }

    public static List<Payment_Processor__c> getActivePaymentProcessors() {
        return [
            SELECT
                Active__c,
                Connected_Account_Token__c,
                Id,
                Test_Mode__c,
                Type__c,
                External_Key__c,    
                PaymentSite_URL__c,
                Last_Sync__c,
                Default_Ledger__c,
                Enable_PaymentSITE_Partial_Payment__c,
                Merchant_GL_Account__c,
                Merchant_Fees_GL_Account__c,
                Bank_GL_Account__c,
                Enable_Convenience_Fees__c,
                Credit_Card_Convenience_Fee_Type__c,
                CC_Flat_Fee__c,
                CC_Percent__c,
                ACH_Flat_Fee__c,
                ACH_Percent__c,
                ACH_Convenience_Fee_Type__c
            FROM Payment_Processor__c
            WHERE Active__c = TRUE
        ];
    }

    public static List<Payment_Processor__c> getPaymentProcessorsForDefaultUpdate(Set<Id> paymentProcessorIds) {
        return [
            SELECT
                Active__c,
                Connected_Account_Token__c,
                Id,
                Test_Mode__c,
                Type__c,
                Global_Default_Payment_Processor__c            
            FROM Payment_Processor__c
            WHERE Id IN :paymentProcessorIds
            OR Global_Default_Payment_Processor__c = TRUE
        ];
    }

    public static List<Payment_Processor__c> getPaymentProcessorsByType(String paymentProcessorType) {
        return [
            SELECT
                Active__c,
                Connected_Account_Token__c,
                Id,
                Name,
                Test_Mode__c,
                Type__c,
                External_Key__c,
                PaymentSite_URL__c,
                Last_Sync__c,
                Default_Ledger__c,
                Enable_PaymentSITE_Partial_Payment__c,
                Merchant_GL_Account__c,
                Merchant_Fees_GL_Account__c,
                Bank_GL_Account__c,
                Enable_Convenience_Fees__c,
                Credit_Card_Convenience_Fee_Type__c,
                Convenience_Fees_GL_Account__c,
                Convenience_Fee_Mapping__c,
                Original_Amount_Mapping__c,
                CC_Flat_Fee__c,
                CC_Percent__c,
                ACH_Convenience_Fee_Type__c,
                ACH_Flat_Fee__c,
                ACH_Percent__c
            FROM Payment_Processor__c
            WHERE Type__c = :paymentProcessorType
        ];
    }

    public static Map<String, List<Payment_Processor_Customer__c>> getPaymentProcessorCustomer(Set<Id> paymentProcessorIds, Set<Id> accountIds) {
        Map<String, List<Payment_Processor_Customer__c>> ppcRecordsByProcessorCustomerKeys = new Map<String, List<Payment_Processor_Customer__c>>();
        List<Payment_Processor_Customer__c> ppcRecords = [
                SELECT Id, Processor__c, Account__c, External_Id__c,
                        Processor__r.Active__c,
                        Processor__r.Connected_Account_Token__c,
                        Processor__r.Id,
                        Processor__r.Test_Mode__c,
                        Processor__r.Type__c
                FROM Payment_Processor_Customer__c
                WHERE Processor__c = :paymentProcessorIds
                AND Account__c = :accountIds
        ];
        for (Payment_Processor_Customer__c ppcRecord : ppcRecords) {
            String key = PaymentProcessorUtils.composeKey(new List<String>{
                    ppcRecord.Processor__c, ppcRecord.Account__c
            });
            List<Payment_Processor_Customer__c> tempRecords = ppcRecordsByProcessorCustomerKeys.containsKey(key) ?
                ppcRecordsByProcessorCustomerKeys.get(key) : new List<Payment_Processor_Customer__c>();
            tempRecords.add(ppcRecord);
            ppcRecordsByProcessorCustomerKeys.put(key, tempRecords);
        }
        return ppcRecordsByProcessorCustomerKeys;
    }

    public static List<Payment_Processor_Customer__c> getPaymentProcessorByCustomers(Set<Id> accountIds) {
        return [
            SELECT Id, Processor__c, Account__c, External_Id__c
            FROM Payment_Processor_Customer__c
            WHERE Account__c IN :accountIds
        ];
    }

    public static List<Payment_Processor_Customer__c> getPaymentProcessorCustomer(Id paymentProcessorId, Id accountId) {
        return [
            SELECT Id, Processor__c, Account__c, External_Id__c         
            FROM Payment_Processor_Customer__c
            WHERE Processor__c = :paymentProcessorId
            AND Account__c = :accountId
        ];
    }

    public static List<Payment_Processor_Customer__c> getPaymentProcessorCustomersByExternalId(Id paymentProcessorId, Set<String> externalIds) {
        return [
            SELECT Id, Processor__c, Account__c, External_Id__c         
            FROM Payment_Processor_Customer__c
            WHERE Processor__c = :paymentProcessorId
            AND External_Id__c IN :externalIds
        ];
    }

    public static Payment_Method__c getPaymentMethod(Id paymentMethodId) {
        List<Payment_Method__c> result = [
            SELECT  Id,
                    Customer__c,
                    Type__c,
                    Payment_Method_Type__c,
                    Bank_Name__c,
                    Status__c,
                    Default__c,
                    Bank_Account_Type__c,
                    Card_Holder_Name__c,
                    Expiration_Month__c,
                    Expiration_Year__c,
                    Last_Four_Digits__c,
                    Payment_Processor__c,
                    Verification_Status__c,
                    External_Id__c
            FROM Payment_Method__c 
            WHERE Id = :paymentMethodId
            LIMIT 1
        ];
        return result == null || result.isEmpty() ? null : result.get(0);
    }

    public static List<Cash_Receipt__c> getCashReceiptByPaymentRef(String paymentRef) {
        return getCashReceiptByPaymentRef(new Set<String>{paymentRef});
    }

    public static List<Cash_Receipt__c> getCashReceiptByPaymentRef(Set<String> paymentRefs) {
        return [
            SELECT Id, Name, Payment_Reference__c
            FROM Cash_Receipt__c 
            WHERE Payment_Reference__c = :paymentRefs
        ];
    }
    
    public static Object getAllBindingsByProviderType(String providertype) {
        try {
            return [
                SELECT Name, Type__c, Is_Active__c, To__c
                FROM BDC_Binding__c
                WHERE Type__c = :providertype
            ];
        } catch (Exception e) {
            throw new UtilityException('An internal error occured while fetching Bindings records based on ' + providertype);
        }
    }

    public static Object updateCustomSettingdata(List<CustomSettingConfig> metaDataUpdates){
        try{
            // fetch all binding recordtypes in map to save  SOql
            Map<String, BDC_Binding__c> mpOfNameAndBindingRec = BDC_Binding__c.getAll();
            //list of binding custom setting records to update
            List<BDC_Binding__c> bindingCustomSettingRecsToUpdate = new List<BDC_Binding__c>();
            
            //loop through all records that coming from LWC
            for(CustomSettingConfig mpUpdate : metaDataUpdates){
                List<String> bindingNames = new List<String>();
                bindingNames.addAll(mpOfNameAndBindingRec.keySet());
                // check the binding record name in map of custom setting records and then extract it
                String bindingName = bindingNames ?.contains(mpUpdate.label) ? bindingNames.get(bindingNames.indexOf(mpUpdate.label)) : null;
                BDC_Binding__c objbinding = mpOfNameAndBindingRec.get(bindingName);
                
                if(objbinding != null){
                    for(String fldApiName : mpUpdate.fieldWithValuesMap.keySet()){
                        objbinding.put(fldApiName, mpUpdate.fieldWithValuesMap.get(fldApiName));
                    }
                    bindingCustomSettingRecsToUpdate.add(objbinding);
                }
                
            }
            //update custom setting
            SFDCSecurityUtils.updateProxy(bindingCustomSettingRecsToUpdate);
            return true;
        }catch(Exception ex){
            throw new UtilityException('An internal error occured while registering/deregistering selected providers');
        }
    }

    public class UtilityException extends Exception {} 
    public static Integer getCountCheckNumberForCashDisbursements() {
        return [
            SELECT COUNT()
            FROM Cash_Disbursement__c
            WHERE Check_Number__c != NULL
            LIMIT 50002
        ];
    }

    public static Decimal getLastCheckNumberForCashDisbursements(Id bankAccountId) {
        Decimal highstChkNum = 0;
        List<Cash_Disbursement__c> result = [
            SELECT Check_Number__c
            FROM Cash_Disbursement__c
            WHERE Bank_Account__c = :bankAccountId
            AND Check_Number__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];
        
        for(Cash_Disbursement__c cd : result){
            if(highstChkNum < cd.Check_Number__c){
                highstChkNum = cd.Check_Number__c;
            }
        }
        return highstChkNum;
    }
    public static List<Bank_Deposit__c> getBankDepositsByBatchId(Set<String> batchIds){
        return [
            SELECT Id,Merchant_Batch_Id__c,Amount__c,Ledger__c,Ledger_Amount__c
            FROM Bank_Deposit__c
            WHERE Merchant_Batch_Id__c IN :batchIds
        ];
    }

    public static List<Account> getCustomerPlaceholderPaymentMethods(Set<Id> customerIds){
        return [
            SELECT Id,
                (
                    SELECT Id, Payment_Method_Type__c, Payment_Processor__c
                    FROM Payment_Methods__r
                    WHERE External_Use_Only__c = TRUE
                )
            FROM Account 
            WHERE Id IN :customerIds
        ];
    }

    public static List<GL_Account_Default__c> glAccountDefaultsByUniqueKeys(Set<String> uniqueKeys) {
        return [
                SELECT Id, Ledger__c, Unique_Key__c, GL_Account_Specification__c, GL_Account__c
                FROM GL_Account_Default__c
                WHERE Unique_Key__c =: uniqueKeys
                LIMIT 10000
        ];
    }

    public static List<GL_Account_Default__c> allGLAccountDefaults() {
        return [
            SELECT Id, Ledger__c, Unique_Key__c, GL_Account_Specification__c, GL_Account__c,GL_Account__r.Name
            FROM GL_Account_Default__c
            LIMIT 10000
        ];
    }


    public static List<GL_Account_Specification__mdt> allGLAccountSpecifications() {
        return [
                SELECT Id,
                        Label,
                        DeveloperName,
                        Help_Text__c,
                        Required__c,
                        Type__c
                FROM GL_Account_Specification__mdt
                ORDER BY Label
                LIMIT 10000
        ];
    }

    public static List<GL_Account_Default__c> gLAccountDefaultsBySpecification(Set<String> specifications) {
        return [
            SELECT Id, Ledger__c, Unique_Key__c, GL_Account_Specification__c, GL_Account__c
            FROM GL_Account_Default__c
            WHERE GL_Account_Specification__c IN :specifications
        ];
    }

    public static List<GL_Account_Default__c> gLAccountDefaultsBySpecsAndLTypes(Set<String> specifications, Set<String> ledgerTypes) {
        return [
                SELECT Id, Ledger__c, Ledger__r.Name, Unique_Key__c, GL_Account_Specification__c, GL_Account__c
                FROM GL_Account_Default__c
                WHERE GL_Account_Specification__c IN :specifications AND Ledger__r.Type__c =: ledgerTypes
        ];
    }

    public static List<GL_Account_Specification__mdt> glAccountSpecifications(Set<String> developerNames) {
        return [
                SELECT Id, DeveloperName, Label,
                Allowed_GL_Sub_Type_1__c,
                Allowed_GL_Types__c,
                Bank_Restriction__c,
                Cash_Flow_Category_Restriction__c,
                Help_Text__c,
                Required__c,
                Restrict_Existing_Transactions_on_Create__c,
                Restrict_Existing_Transactions_on_Edit__c,
                Type__c
            FROM GL_Account_Specification__mdt
            WHERE DeveloperName =: developerNames
        ];
    }

    public static List<Payment_Activity__c> getPaymentActivitiesByCardknoxRefNum(Set<String> cardknoxRefNums) {
        return [
            SELECT Id, Merchant_Reference__c, Payment_Method__c
            FROM Payment_Activity__c
            WHERE Merchant_Reference__c IN :cardknoxRefNums
        ];
    }
    
    public static Database.QueryLocator getQueryLocatorForCxTxnsUpdateBatch(DateTime endDateTime, Set<Id> paymentProcessorIds, Set<String> excludeMerchantBatchIds){
        // extra bind varialbe
        String processorType = PaymentProcessorActions.CARDKNOX_TYPE;
        
        Date endDate = endDateTime.dateGMT();

        String q = 
            'SELECT ' +
                'Id, ' +
                'Name, ' + 
                'Merchant_Reference__c, ' + 
                'Merchant_Batch_Id__c, ' +
                'Fee__c, ' +
                'Status__c, ' +
                'Amount__c, ' + 
                'Error_Message__c, ' +
                'Error_Type__c, ' +
                'Payment_Method__c, ' + 
                'Cash_Receipt__c, ' +
                'Type__c, ' +
                'Payment_Date__c, ' +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'CurrencyIsoCode, ' : '') +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'Cash_Receipt__r.CurrencyIsoCode, ' : '') +
                'Cash_Receipt__r.Name, ' +
                'Payment_Method__r.Payment_Processor__c, ' +
                'Cash_Receipt__r.Credit_GL_Account__c, ' +
                'Cash_Receipt__r.Amount__c, ' +
                'Cash_Receipt__r.Receipt_Date__c, ' +
                'Cash_Receipt__r.Payment_Reference__c, ' +
                'Cash_Receipt__r.Ledger__c, ' +
                'Cash_Receipt__r.Bank_Deposit__c, ' +
                'Payment_Method__r.Payment_Processor__r.Merchant_GL_Account__c ' +
            'FROM Payment_Activity__c ' +
            'WHERE Cash_Receipt__c != NULL '+ 
            'AND Cash_Receipt__r.Bank_Deposit__c = NULL ' +
            'AND Payment_Method__r.Payment_Processor__r.Type__c = :processorType ' +
            'AND Payment_Method__r.Payment_Processor__r.Active__c = TRUE ' +
            'AND ( ' +
                '(Payment_Date__c = NULL AND Cash_Receipt__r.Receipt_Date__c <= :endDate) ' +
                'OR ' +
                '(Payment_Date__c <> NULL AND Payment_Date__c <= :endDateTime) ' +
            ') ' +
            'AND Payment_Method__r.Payment_Processor__c IN :paymentProcessorIds ' +
            'AND Merchant_Batch_Id__c <> NULL ' +
            'AND Merchant_Batch_Id__c NOT IN :excludeMerchantBatchIds ' +
            'ORDER BY Cash_Receipt__r.Receipt_Date__c';
        
        return Database.getQueryLocator(q);
    }

    public static List<Transaction_Import_Error__c> getTransactionImportErrorByRefNum(Set<String> refNums){
        return [
            SELECT Id, Merchant_Reference__c, Customer__c, Billing__c 
            FROM Transaction_Import_Error__c
            WHERE Merchant_Reference__c IN :refNums
        ];
    }
    
    public static Automated_Job_Results__c getAutomatedJobResultsById(Id ajrId){
        List<Automated_Job_Results__c> ajrRecords =  [
                                SELECT Id, Processed__c, Succeeded__c, Failed__c, Notes__c 
                                FROM Automated_Job_Results__c 
                                WHERE Id = :ajrId
                            ];
        return ajrRecords.size() >= 1 ? ajrRecords[0] : null;
    }

    public static List<Task> getTasksByIds(Set<Id> taskIds) {
        return [SELECT Id, WhatId, Description FROM Task WHERE Id IN :taskIds];
    }
    
    public static List<Cash_Disbursement__c> getCashDisbursementByIdWithPostedStatus(Set<Id> ids) {
        List<Cash_Disbursement__c> result = [
            SELECT Id,
                Source__c,
                Status__c
            FROM Cash_Disbursement__c
            WHERE Id IN :ids AND Status__c ='Posted' AND Source__c = 'Payable'
        ];
        return result;
    }

    public static List<String> getTransactionGroupFields() {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Amortization_Entry__c',
            'AP_Disbursement__c',
            'Batch_Id__c',
            'Billing__c',
            'Billing_Cash_Receipt__c',
            'Cash_Disbursement__c',
            'Cash_Receipt__c',
            'Journal_Entry__c',
            'Ledger__c',
            'Line_Count__c',
            'Lines_Processed__c',
            'Account_Payable__c',
            'Time_Card__c',
            'Recurring_Billing__c',
            'Recurring_Account_Payable__c',
            'Recurring_Journal_Entry__c',
            'Status__c'
        };
        return fieldsToQuery;
    }
    public static List<Transaction_Group__c> getTransactionGroupBySourceId(Set<Id> sourceIds) {
        String queryCondition = new List<Id> (sourceIds)[0].getSObjectType() + ' IN :sourceIds';
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            getTransactionGroupFields(),
            null,
            Transaction_Group__c.SObjectType,
            queryCondition,
            false,
            false
        );
        return (List<Transaction_Group__c>) Database.query(dynamicSOQL);
    }
    public static List<Transaction_Group__c> getTransactionGroupBySourceAndBatchId(Set<Id> sourceIds,String batchId) {
        String queryCondition = new List<Id> (sourceIds)[0].getSObjectType() + ' IN :sourceIds AND Batch_Id__c = :batchId';
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            getTransactionGroupFields(),
            null,
            Transaction_Group__c.SObjectType,
            queryCondition,
            false,
            false
        );
        return (List<Transaction_Group__c>) Database.query(dynamicSOQL);
    }

    public static List<Payment_Proposal__c> getPaymentProposalsById(Set<Id> paymentProposalIds) {

        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Account__c',
            'Aggregate_by_Payee__c',
            'Alternate_Payee__c',
            'Conditions_Met__c',
            'Payable_Name__c',
            'Payee_Reference__c',
            'Relative_Due_Date_Number_n__c',
            'Payment_Proposal_Date__c',
            'Proprietary_Payable_Number__c',
            'Relative_Due_Date__c',
            'Relative_Early_Pay_Date_Number_n__c',
            'Relative_Early_Pay_Date__c',
            'Relative_Issue_Date_Number_n__c',
            'Relative_Issue_Date__c',
            'Payable_Name_Operator__c',
            'Payee_Reference_Operator__c',
            'Alternate_Payee_Operator__c',
            'Proprietary_Payable_Number_Operator__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fieldsToQuery.add('CurrencyIsoCode');
        }
        //Add query condition
        String queryCondition = 'Id IN :paymentProposalIds';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Payment_Proposal__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        //Call DML operation
        return Database.query(theQuery.toSOQL());

    }
    public static List<Account> getAccountsByIdWithPP(Set<Id> ids) {
        List<String> queryFields = new List<String>{
            'Id',
            'Default_Payment_Processor__c'
        };
        String queryString = 'SELECT ' + String.join(queryFields, ',') + ' FROM Account WHERE Id IN :ids AND Default_Payment_Processor__c != null';
        
        return (List<Account>) Database.query(queryString);
    }
    public static List<Ledger__c> getLedgersByIdWithPP(Set<Id> ids) {
        List<String> queryFields = new List<String>{
            'Id',
            'Default_Payment_Processor__c'
        };
        String queryString = 'SELECT ' + String.join(queryFields, ',') + ' FROM Ledger__c WHERE Id IN :ids AND Default_Payment_Processor__c != null';
        
        return (List<Ledger__c>) Database.query(queryString);
    }

    public static List<Payment_Proposal_Line__c> getPaymentProposalLinesByParentId(List<Id> parentIds) {
        List<String> fieldsToQuery = new List<String> {
                'Id',
                'Name',
                'Parent__c',
                'Amount__c',
                'Is_Credit__c',
                'Current_Balance__c'
        };

        String queryCondition = 'Parent__c IN :parentIds';

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Proposal_Line__c.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(false)
                .selectFields(fieldsToQuery)
                .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }
    public static List<Billing_Cash_Receipt__c> getBillingCashReceiptsById(Set<Id> ids) {
        List<Billing_Cash_Receipt__c> result = [
            SELECT  Id,
                CreatedDate,
                Status__c,
                Accounting_Period__c,
                Accounting_Period__r.Status__c,
                Cash_Receipt__r.Ledger__c,
                Cash_Receipt__r.Credit_GL_Account__c,
                Cash_Receipt__r.Currency_Conversion_Rate__c,
                Billing__r.Ledger__c,
                Billing__c,
                Applied_Amount__c
            FROM Billing_Cash_Receipt__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static List<Recurring_Billing__c> getRecurringBillingsById(Set<Id> ids,Boolean isOpportunityAvailable) {
        String query = 
            'SELECT ' +
                'Id ,' +
                'Name ,' +
                'Status__c ,' +
                'Next_Billing_Date__c ,' +
                'Last_Billing_Date__c ,' +
                'Billing_Frequency__c ,' +
                'Ledger__c ,' +
                'Sub_Total__c ,' +
                'Sales_Tax__c ,' +
                'Customer__c ,' +
                'Billing_Contact__c ,' +
                'Comment__c ,' +
                'Customer__r.ShippingStreet ,' +
                'Customer__r.ShippingCity ,' +
                'Customer__r.ShippingState ,' +
                'Customer__r.ShippingCountry, '+
                'Customer__r.ShippingPostalCode ,' +
                'Customer__r.VAT_Business_Identification_Number__c ,' +
                'Customer__r.Entity_Use_Code__c ,' +
                'Customer__r.Exemption_Number__c, '+ 
                (isOpportunityAvailable ? 'Opportunity__c, ' : '') +
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'CurrencyIsoCode, ' : '') +
                'PO_Number__c ' +
            ' FROM Recurring_Billing__c ' +
            ' WHERE Id IN :ids';
        
        return (List<Recurring_Billing__c>)Database.query(query);
    }
    public static List<Recurring_Account_Payable__c> getRecurringAccountPayableByIds(Set<Id> ids) {
        String query = 
                'SELECT ' +
                    'Id, '+
                    'Name, '+
                    'Vendor__c, '+
                    'Contact__c, '+
                    'Employee__c, '+
                    'Status__c, '+
                    'Next_Account_Payable_Date__c, '+
                    'Last_Account_Payable_Date__c, '+
                    'Account_Payable_Frequency__c, '+
                    'Ledger__c, '+
                    'Purchase_Tax__c, '+
                    (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'CurrencyIsoCode, ' : '') +
                    'Sub_Total__c ' +
                ' FROM Recurring_Account_Payable__c ' +
                ' WHERE Id IN :ids';

        return (List<Recurring_Account_Payable__c>) Database.query(query);
    }
    public static List<Recurring_Journal_Entry__c> getRecurringJEById(Set<Id> ids) {
        String query = 
            'SELECT ' +
                'Id, '+
                'Name, '+
                'Auto_Reverse__c, '+
                'Status__c, '+
                'Next_Journal_Entry_Date__c, '+
                'Last_Journal_Entry_Date__c, '+
                'Journal_Entry_Frequency__c, '+
                'Ledger__c, '+
                'Out_of_Balance__c, '+
                'Total_Credits__c, '+
                'Total_Debits__c, '+
                'Reference__c, '+
                (MultiCurrencyHandler.isMultiCurrencyEnabled ? 'CurrencyIsoCode, ' : '') +
                'Type__c ' +
            ' FROM Recurring_Journal_Entry__c ' +
            ' WHERE Id IN :ids';
        
        return (List<Recurring_Journal_Entry__c>)Database.query(query);
    }
    public static Map<Id, AggregateResult> getRecurringBillingLinesCountByRecBilling(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT  count(Id) lineCount, Recurring_Billing__c Id
            FROM Recurring_Billing_Line__c
            WHERE Recurring_Billing__c IN :ids
            GROUP BY Recurring_Billing__c]);
    }
    public static Map<Id, AggregateResult> getRecAccPayablelinesCountByRecAccPayable(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT  count(Id) lineCount, Recurring_Account_Payable__c Id
            FROM Recurring_Account_Payable_Line__c
            WHERE Recurring_Account_Payable__c IN :ids
            GROUP BY Recurring_Account_Payable__c]);
    }
    public static Map<Id, AggregateResult> getRecurringJournalEntryLinesCountByRecJE(Set<Id> ids) {
        return new Map<Id, AggregateResult>(
            [SELECT  count(Id) lineCount, Recurring_Journal_Entry__c Id
            FROM Recurring_Journal_Entry_Line__c
            WHERE Recurring_Journal_Entry__c IN :ids
            GROUP BY Recurring_Journal_Entry__c]);
    }

    public static List<Bank_Disbursement__c> getBankDisbursementById(Set<Id> ids) {
        List<Bank_Disbursement__c> result = [
            SELECT  Id,
                    (SELECT Id FROM AcctSeed__Cash_Disbursements__r LIMIT 1),
                    (SELECT Id FROM AcctSeed__Journal_Entry_Lines__r LIMIT 1)
            FROM AcctSeed__Bank_Disbursement__c
            WHERE Id IN :ids
        ];
        return result;
    }

    public static Map<Id, Bank_Disbursement__c> getBankDisbursements(Set<Id> bankDisbIds) {
        Map<Id, Bank_Disbursement__c> resultMap = new Map<Id, Bank_Disbursement__c>();
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Bank_GL_Account__c', 
            'Disbursement_Date__c',
            'Bank_Reconciliation__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };

        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :bankDisbIds';   
        
        SOQLBuilder theQuery = new SOQLBuilder(Bank_Disbursement__c.getSObjectType());
        theQuery
            .assertIsAccessible()
            .selectFields(queryFields)
            .setCondition(queryCondition);

        for (Bank_Disbursement__c bankDisb : (List<Bank_Disbursement__c>) Database.query(theQuery.toSOQL())) {
            resultMap.put(bankDisb.Id, bankDisb);
        }

        return resultMap;
    }

    public static Map<Id,AggregateResult> getCashDisbAmountSumByBankDis(Set<Id> queryIds) {
        Map<Id, AggregateResult> results = new Map<Id, AggregateResult>();
        for(AggregateResult aR : Database.query(
            'SELECT Bank_Disbursement__c Id, SUM(Amount_Number__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' + 
            'FROM Cash_Disbursement__c ' + 
            'WHERE Bank_Disbursement__c in :queryIds ' + 
            'GROUP BY Bank_Disbursement__c'  
        )){
            results.put((Id)aR.get('Id'), aR);
        }
        return results;
    }

    public static Map<Id,AggregateResult> getCreditJEAmountSumByBankDis(Set<Id> queryIds) {
        Map<Id, AggregateResult> results = new Map<Id, AggregateResult>();
        for(AggregateResult aR : Database.query(
            'SELECT Bank_Disbursement__c Id, SUM(Amount_Number__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' + 
            'FROM Journal_Entry_Line__c ' + 
            'WHERE Bank_Disbursement__c in :queryIds ' + 
            'AND Credit__c != NULL ' + 
            'GROUP BY Bank_Disbursement__c'  
        )){
            results.put((Id)aR.get('Id'), aR);
        }
        return results;
    }
    
    public static Map<Id,AggregateResult> getDebitJEAmountSumByBankDis(Set<Id> queryIds) {
        Map<Id, AggregateResult> results = new Map<Id, AggregateResult>();
        for(AggregateResult aR : Database.query(
            'SELECT Bank_Disbursement__c Id, SUM(Amount_Number__c) amountSum, SUM(Ledger_Amount__c) ledgerAmountSum ' + 
            'FROM Journal_Entry_Line__c ' + 
            'WHERE Bank_Disbursement__c in :queryIds ' + 
            'AND Debit__c != NULL ' + 
            'GROUP BY Bank_Disbursement__c'  
        )){
            results.put((Id)aR.get('Id'), aR);
        }
        return results;
    }

    public static List<ContentWorkSpace> getContentWorkSpace(String libraryName){
        List<ContentWorkSpace> contentWorkspace = new List<ContentWorkSpace>();
        try{
            contentWorkspace = [SELECT Name FROM ContentWorkSpace WHERE Name =: libraryName];
        }catch(Exception exc){
            throw exc;
        }
        return contentWorkspace;
    }

}