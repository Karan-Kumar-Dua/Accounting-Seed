public with sharing class ExpenseReportHelper {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String FIELD_SET_API_NAME = PACKAGE_QUALIFIER + 'ExpenseReportEdit';

    private static List<Schema.FieldSetMember> getFieldSetMembers() {
        FieldSet fs = Schema.SObjectType.Expense_Line__c.fieldSets.getMap().get(FIELD_SET_API_NAME);
        return fs.getFields();
    }

    private static List<String> getFieldApiNamesFromFieldSetToQuery() {
        List<String> result = new List<String>();
        for (Schema.FieldSetMember fsMember : getFieldSetMembers()) {
            result.add(fsMember.getFieldPath());
            //add Name field for any lookups
            if (fsMember.getType() == Schema.DisplayType.REFERENCE) {
                result.add(fsMember.getFieldPath().replaceAll('__c$', '__r.') + 'Name');
            }
        }

        return result;
    }

    @AuraEnabled
    public static ExpenseReportHelper.ExpenseReportData getExpenseReportData(String expenseReportId) {
        try {
            Expense_Report__c theExpenseReport = queryExpenseReport(expenseReportId);
            return new ExpenseReportHelper.ExpenseReportData(theExpenseReport);
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void saveExpenseLines(String expenseReportId, List<String> serializedExpenseLineWrappers) {
        try {
            List<Expense_Line__c> linesToUpdate = new List<Expense_Line__c>();
            for (String eachSerializedLine : serializedExpenseLineWrappers) {
                ExpenseLineData lineData = (ExpenseLineData) JSON.deserialize(eachSerializedLine, ExpenseLineData.class);
                linesToUpdate.add(lineData.getExpenseLine(expenseReportId));
            }
            SFDCSecurityUtils.upsertCheckCRUDAndFLS(linesToUpdate, new List<String>{
                'Billable__c',
                'Employee_Reimburse__c',
                'Mileage_Origin__c',
                'Mileage_Destination__c',
                'Miles__c',
                'Internal_Comment__c',
                'Invoice_Comment__c',
                'Credit_Card_Vendor__c'
            });
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteExpenseLine(String expenseLineId) {
        try {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(new Expense_Line__c(Id = expenseLineId));
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public static List<Expense_Line__c> queryExpenseLines(Id expReportId) {
        //Prepare SOQL Query to query Expense Lines with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Expense_Report__c', 'Project__c'
        };

        String queryCondition =
            'Expense_Report__c = :expReportId ORDER BY Project__r.Name, Project_Task__r.Name';

        SOQLBuilder theQuery = new SOQLBuilder(Expense_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        //============================================================================
        return (List<Expense_Line__c>) Database.query(theQuery.toSOQL());
    }

    public static List<GL_Account__c> queryGlAccounts() {
        //Prepare SOQL Query to query Accounts with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Type__c', 'Expense_Report_Name__c', 'Mileage_Account__c', 'Mileage_Rate__c'
        };

        String queryCondition =
            'Type__c != \'Cash Flow\' AND Used_in_Expense_Reports__c = true AND Active__c = true ORDER BY Name LIMIT 1000';

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        //============================================================================
        return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }

    // Security Review Note: This class is a controller extension and the fields queried are exposed via Visualforce.
    // Hence, FLS is handled by Visualforce page.
    public static Expense_Report__c queryExpenseReport(String expenseReportId) {
        //Prepare SOQL Query to query Expense Report
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Employee__c', 'Status__c', 'Total_Expenses__c', 'CreatedDate', 'Ledger__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id = :expenseReportId';

        List<String> subQueryFields = new List<String>{
            'Name',
            'Expense_Report__c',
            'Project__c',
            'Project__r.Name',
            'Project_Task__c',
            'Project_Task__r.Name',
            'Amount__c',
            'Billable__c',
            'Internal_Comment__c',
            'Invoice_Comment__c',
            'Date__c',
            'Expense_GL_Account__c',
            'Expense_GL_Account__r.Name',
            'Expense_GL_Account__r.Expense_Report_Name__c',
            'Expense_GL_Account__r.Mileage_Rate__c',
            'Employee_Reimburse__c',
            'Mileage_Origin__c',
            'Mileage_Destination__c',
            'Miles__c',
            'Credit_Card_Vendor__c',
            'Credit_Card_Vendor__r.Name'
        };

        subQueryFields.addAll(getFieldApiNamesFromFieldSetToQuery());

        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Expense_Lines__r';
        SOQLBuilder.Ordering subqueryOrdering = new SOQLBuilder.Ordering('Expense_Line__c', 'Name', SOQLBuilder.SortOrder.DESCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Expense_Report__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(subQueryFields)
            .addOrdering(subqueryOrdering);
        //============================================================================
        return (Expense_Report__c) Database.query(theQuery.toSOQL());
    }

    public static List<Account> queryCreditCardVendors() {
        //Prepare SOQL Query to query Accounts with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name'
        };

        String queryCondition = 'Credit_Card_Vendor__c = true';

        SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        //============================================================================
        return (List<Account>) Database.query(theQuery.toSOQL());
    }

    public class ExpenseReportData {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public ExpenseLineData secureLine;
        @AuraEnabled
        public List<ExpenseLineData> expenseLines;
        @AuraEnabled
        public List<ExpenseLineData> mileageLines;
        @AuraEnabled
        public List<CustomSelectOption> creditCardVendors;
        @AuraEnabled
        public List<CustomSelectOption> expensesExpTypes;
        @AuraEnabled
        public List<CustomSelectOption> mileageExpTypes;
        @AuraEnabled
        public Boolean showCreditCardVendor;
        @AuraEnabled
        public Boolean isCreditCardVendorUpdateable;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public Boolean isEditModeAvailable;

        public ExpenseReportData(Expense_Report__c expenseReport) {
            this.id = expenseReport.Id;
            this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.isEditModeAvailable =
                Expense_Line__c.SObjectType.getDescribe().isCreateable()
                    && Expense_Line__c.SObjectType.getDescribe().isUpdateable();
            this.currencyIsoCode = getExpenseReportIsoCode(expenseReport);
            this.creditCardVendors = getCreditCardVendors();
            this.showCreditCardVendor = !this.creditCardVendors.isEmpty() && Expense_Line__c.Credit_Card_Vendor__c.getDescribe().isAccessible();
            this.isCreditCardVendorUpdateable = Expense_Line__c.Credit_Card_Vendor__c.getDescribe().isUpdateable();
            getExpenseTypes();
            this.secureLine = new ExpenseLineData(new Expense_Line__c());
            getExpenseLines(expenseReport.Expense_Lines__r);
        }

        private String getExpenseReportIsoCode(Expense_Report__c expenseReport) {
            String result = MultiCurrencyHandler.CORPORATE_CURRENCY;
            if (this.isMultiCurrencyEnabled) {
                result = (String) expenseReport.get('CurrencyIsoCode');
            }
            return result;
        }

        private List<CustomSelectOption> getCreditCardVendors() {
            List<CustomSelectOption> result = new List<CustomSelectOption>();
            for (Account acc : queryCreditCardVendors()) {
                result.add(new CustomSelectOption(acc));
            }
            //add -None- option if there is CC Vendor available
            if (!result.isEmpty()) {
                result.add(0, new CustomSelectOption(NULL, '-' + Label.COMMON_NONE + '-'));
            }
            return result;
        }

        private void getExpenseLines(List<Expense_Line__c> allLines) {
            this.expenseLines = new List<ExpenseLineData>();
            this.mileageLines = new List<ExpenseLineData>();

            for (Expense_Line__c expenseLine : allLines) {
                ExpenseLineData eLineData = new ExpenseLineData(expenseLine);

                if (eLineData.isMileageExpenseLine) {
                    mileageLines.add(eLineData);
                }
                else {
                    expenseLines.add(eLineData);
                }
            }
        }

        private void getExpenseTypes() {
            this.mileageExpTypes = new List<CustomSelectOption>();
            this.expensesExpTypes = new List<CustomSelectOption>();
            for (GL_Account__c glAccount : ExpenseReportHelper.queryGlAccounts()) {
                if (glAccount.Mileage_Account__c) {
                    if (glAccount.Expense_Report_Name__c != NULL) {
                        this.mileageExpTypes.add(new CustomSelectOption(glAccount.Id, glAccount.Expense_Report_Name__c));
                    }
                    else {
                        this.mileageExpTypes.add(new CustomSelectOption(glAccount));
                    }
                }
                else {
                    if (glAccount.Expense_Report_Name__c != NULL) {
                        this.expensesExpTypes.add(new CustomSelectOption(glAccount.Id, glAccount.Expense_Report_Name__c));
                    }
                    else {
                        this.expensesExpTypes.add(new CustomSelectOption(glAccount));
                    }
                }
            }
        }
    }

    public class ExpenseLineData {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public CustomLookupFieldValue project;
        @AuraEnabled
        public CustomLookupFieldValue projectTask;
        @AuraEnabled
        public CustomPrimitiveFieldValue billable;
        @AuraEnabled
        public CustomPrimitiveFieldValue reimburse;
        @AuraEnabled
        public CustomPrimitiveFieldValue lineDate;
        @AuraEnabled
        public CustomLookupFieldValue expenseType;
        @AuraEnabled
        public CustomLookupFieldValue creditCardVendor;
        @AuraEnabled
        public CustomPrimitiveFieldValue mileageOrigin;
        @AuraEnabled
        public CustomPrimitiveFieldValue mileageDestination;
        @AuraEnabled
        public CustomPrimitiveFieldValue miles;
        @AuraEnabled
        public Decimal mileageRate;
        @AuraEnabled
        public CustomPrimitiveFieldValue amount;
        @AuraEnabled
        public CustomPrimitiveFieldValue internalComment;
        @AuraEnabled
        public CustomPrimitiveFieldValue invoiceComment;
        @AuraEnabled
        public List<CustomFieldSetMember> dynamicFields;

        public Boolean isMileageExpenseLine;

        public ExpenseLineData(Expense_Line__c expenseLine) {
            this.id = expenseLine.Id;
            this.name = expenseLine.Name;
            this.project = new CustomLookupFieldValue(
                expenseLine.Project__c,
                expenseLine.Project__r.Name,
                Schema.SObjectType.Expense_Line__c.fields.Project__c
            );
            this.projectTask = new CustomLookupFieldValue(
                expenseLine.Project_Task__c,
                expenseLine.Project_Task__r.Name,
                Schema.SObjectType.Expense_Line__c.fields.Project_Task__c
            );
            this.billable = new CustomPrimitiveFieldValue(expenseLine.Billable__c, Schema.SObjectType.Expense_Line__c.fields.Billable__c);
            this.reimburse = new CustomPrimitiveFieldValue(expenseLine.Employee_Reimburse__c, Schema.SObjectType.Expense_Line__c.fields.Employee_Reimburse__c);
            this.lineDate = new CustomPrimitiveFieldValue(expenseLine.Date__c, Schema.SObjectType.Expense_Line__c.fields.Date__c);
            this.mileageOrigin = new CustomPrimitiveFieldValue(expenseLine.Mileage_Origin__c, Schema.SObjectType.Expense_Line__c.fields.Mileage_Origin__c);
            this.mileageDestination = new CustomPrimitiveFieldValue(expenseLine.Mileage_Destination__c, Schema.SObjectType.Expense_Line__c.fields.Mileage_Destination__c);
            this.miles = new CustomPrimitiveFieldValue(expenseLine.Miles__c, Schema.SObjectType.Expense_Line__c.fields.Miles__c);
            this.mileageRate = expenseLine.Expense_GL_Account__r.Mileage_Rate__c;//FLS ignored -> for internal use only
            this.amount = new CustomPrimitiveFieldValue(expenseLine.Amount__c, Schema.SObjectType.Expense_Line__c.fields.Amount__c);
            this.internalComment = new CustomPrimitiveFieldValue(expenseLine.Internal_Comment__c, Schema.SObjectType.Expense_Line__c.fields.Internal_Comment__c);
            this.invoiceComment = new CustomPrimitiveFieldValue(expenseLine.Invoice_Comment__c, Schema.SObjectType.Expense_Line__c.fields.Invoice_Comment__c);
            this.expenseType = new CustomLookupFieldValue(
                expenseLine.Expense_GL_Account__c,
                ((expenseLine.Expense_GL_Account__r.Expense_Report_Name__c != NULL)
                    ? expenseLine.Expense_GL_Account__r.Expense_Report_Name__c
                    : expenseLine.Expense_GL_Account__r.Name),
                Schema.SObjectType.Expense_Line__c.fields.Expense_GL_Account__c
            );
            this.creditCardVendor = new CustomLookupFieldValue(
                expenseLine.Credit_Card_Vendor__c,
                expenseLine.Credit_Card_Vendor__r.Name,
                Schema.SObjectType.Expense_Line__c.fields.Credit_Card_Vendor__c
            );
            this.isMileageExpenseLine = expenseLine.Miles__c != NULL;
            this.dynamicFields = getDynamicFields(expenseLine);
        }

        private List<CustomFieldSetMember> getDynamicFields(Expense_Line__c expenseLine) {
            List<CustomFieldSetMember> result = new List<CustomFieldSetMember>();
            List<FieldSetMember> sfMembers = getFieldSetMembers();
            for (FieldSetMember sfMember : sfMembers) {
                CustomFieldSetMember tempCustomFieldSetMember = new CustomFieldSetMember(sfMember, expenseLine);
                result.add(tempCustomFieldSetMember);
            }
            return result;
        }

        public Expense_Line__c getExpenseLine(String expenseReportId) {
            return new Expense_Line__c(
                Id = this.id,
                Expense_Report__c = expenseReportId,
                Project__c = this.project.id,
                Project_Task__c = this.projectTask.id,
                Billable__c = this.billable.booleanValue,
                Employee_Reimburse__c = this.reimburse.booleanValue,
                Date__c = this.lineDate.dateValue,
                Mileage_Origin__c = this.mileageOrigin.stringValue,
                Mileage_Destination__c = this.mileageDestination.stringValue,
                Miles__c = this.miles.decimalValue,
                Amount__c = this.amount.decimalValue,
                Internal_Comment__c = this.internalComment.stringValue,
                Invoice_Comment__c = this.invoiceComment.stringValue,
                Expense_GL_Account__c = this.expenseType.id,
                Credit_Card_Vendor__c = this.creditCardVendor.id
            );
        }
    }

    public with sharing class CustomSelectOption {
        @AuraEnabled
        public String value {get; set;}
        @AuraEnabled
        public String label {get; set;}

        public CustomSelectOption(SObject record) {
            this.value = record.Id;
            this.label = (String) record.get('Name');
        }

        public CustomSelectOption(String aId, String aName) {
            this.value = aId;
            this.label = aName;
        }
    }

    public with sharing class CustomFieldSetMember {
        @AuraEnabled
        public Boolean dbRequired;
        @AuraEnabled
        public String fieldPath;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Boolean required;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public CustomLookupFieldValue lookupFieldValue;
        @AuraEnabled
        public CustomPrimitiveFieldValue primitiveFieldValue;

        public CustomFieldSetMember(Schema.FieldSetMember fsm, Expense_Line__c expenseLine) {
            this.dbRequired = fsm.getDbRequired();
            this.fieldPath = fsm.getFieldPath();
            this.label = fsm.getLabel();
            this.required = fsm.getRequired();
            this.type = convertDisplayTypeToCustomType(fsm.getType());

            if (this.type == 'REFERENCE') {
                String lookupRecordName =
                    (expenseLine.getSObject(this.fieldPath.replaceAll('__c$', '__r')) != NULL)
                        ? (String) expenseLine.getSObject(this.fieldPath.replaceAll('__c$', '__r')).get('Name')
                        : NULL;
                this.lookupFieldValue = new CustomLookupFieldValue(
                    (Id) expenseLine.get(this.fieldPath),
                    lookupRecordName,
                    Schema.SObjectType.Expense_Line__c.fields.getMap().get(this.fieldPath).getDescribe()
                );
            }
            else {
                this.primitiveFieldValue = new CustomPrimitiveFieldValue(
                    expenseLine.get(this.fieldPath),
                    Schema.SObjectType.Expense_Line__c.fields.getMap().get(this.fieldPath).getDescribe()
                );
            }
        }

        private String convertDisplayTypeToCustomType(Schema.DisplayType dt) {
            String customType;
            if (dt == Schema.DisplayType.REFERENCE) {
                customType = 'REFERENCE';
            }
            else if (dt == Schema.DisplayType.BOOLEAN) {
                customType = 'BOOLEAN';
            }
            else if (dt == Schema.DisplayType.INTEGER
                        || dt == Schema.DisplayType.DOUBLE
                        || dt == Schema.DisplayType.LONG
                        || dt == Schema.DisplayType.CURRENCY) {

                customType = 'NUMBER';
            }
            else if (dt == Schema.DisplayType.DATE
                        || dt == Schema.DisplayType.DATETIME) {

                customType = 'DATE';
            }
            else {
                customType = 'STRING';
            }

            return customType;
        }
    }

    public with sharing class CustomLookupFieldValue {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String fieldLabel;
        @AuraEnabled
        public Boolean isAccessible;
        @AuraEnabled
        public Boolean isUpdateable;
        @AuraEnabled
        public Boolean isCreateable;

        public CustomLookupFieldValue(Id id, String name, DescribeFieldResult fieldResult) {
            this.id = id;
            this.name = name;
            this.fieldLabel = fieldResult.getLabel();
            this.isAccessible = fieldResult.isAccessible();
            this.isUpdateable = fieldResult.isUpdateable();
            this.isCreateable = fieldResult.isCreateable();
        }
    }

    public with sharing class CustomPrimitiveFieldValue {
        @AuraEnabled
        public String stringValue;
        @AuraEnabled
        public Boolean booleanValue;
        @AuraEnabled
        public Date dateValue;
        @AuraEnabled
        public Decimal decimalValue;
        @AuraEnabled
        public String fieldLabel;
        @AuraEnabled
        public Boolean isAccessible;
        @AuraEnabled
        public Boolean isUpdateable;
        @AuraEnabled
        public Boolean isCreateable;

        public CustomPrimitiveFieldValue(DescribeFieldResult fieldResult) {
            this.fieldLabel = fieldResult.getLabel();
            this.isAccessible = fieldResult.isAccessible();
            this.isUpdateable = fieldResult.isUpdateable();
            this.isCreateable = fieldResult.isCreateable();
        }

        public CustomPrimitiveFieldValue(Object value, DescribeFieldResult fieldResult) {
            if (fieldResult.getType() == Schema.DisplayType.BOOLEAN) {
                this((Boolean) value, fieldResult);
            }
            else if (fieldResult.getType() == Schema.DisplayType.INTEGER
                        || fieldResult.getType() == Schema.DisplayType.DOUBLE
                        || fieldResult.getType() == Schema.DisplayType.LONG
                        || fieldResult.getType() == Schema.DisplayType.CURRENCY) {

                this((Decimal) value, fieldResult);
            }
            else if (fieldResult.getType() == Schema.DisplayType.DATE) {
                this((Date) value, fieldResult);
            }
            else if (fieldResult.getType() == Schema.DisplayType.DATETIME) {
                this((Datetime) value, fieldResult);
            }
            else {
                this((String) value, fieldResult);
            }
        }

        public CustomPrimitiveFieldValue(String value, DescribeFieldResult fieldResult) {
            this(fieldResult);
            this.stringValue = value;
        }

        public CustomPrimitiveFieldValue(Boolean value, DescribeFieldResult fieldResult) {
            this(fieldResult);
            this.booleanValue = value;
        }

        public CustomPrimitiveFieldValue(Date value, DescribeFieldResult fieldResult) {
            this(fieldResult);
            this.dateValue = value;
        }

        public CustomPrimitiveFieldValue(Datetime value, DescribeFieldResult fieldResult) {
            this(fieldResult);
            this.dateValue = (value != NULL) ? value.date() : NULL;
        }

        public CustomPrimitiveFieldValue(Decimal value, DescribeFieldResult fieldResult) {
            this(fieldResult);
            this.decimalValue = value;
        }
    }

}