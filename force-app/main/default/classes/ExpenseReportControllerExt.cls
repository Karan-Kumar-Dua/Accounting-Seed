public with sharing class ExpenseReportControllerExt {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private Map<Id, GL_Account__c> expenseTypesMap;
    private Boolean isExpenseError;
    private Boolean isMileageError;
    private Boolean isReimburseAndCCVendorError;
    private Boolean isExpenseInserted;
    private Integer expenseRowNum;
    private Integer mileageRowNum;
    private List<Expense_Line__c> removedRowsList;

    public Expense_Report__c expReport {get; set;}
    public Integer selectedExpenseRow {get; set;}
    public Integer selectedMileageRow {get; set;}
    public Boolean isNameError {get; set;}
    public Boolean isReportDateError {get; set;}
    public Boolean isEmployeeError {get; set;}
    public Boolean isStatusError {get; set;}
    public Boolean isError {get; set;}
    public List<SelectOption> expenseTypesList {get; set;}
    public List<SelectOption> mileageTypesList {get; set;}
    public List<SelectOption> ccVendorList {get; set;}
    public Map<Integer, ExpenseLineWrapper> expensesMap {get; set;}
    public Map<Integer, ExpenseLineWrapper> mileageMap {get; set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public String currencyIsoCode {get; set;}
    public static List<Schema.FieldSetMember> expenseReportEditFieldSet {
        get {
            if (expenseReportEditFieldSet == NULL) {
                expenseReportEditFieldSet = Schema.SObjectType.Expense_Line__c.fieldSets.getMap().get(PACKAGE_QUALIFIER + 'ExpenseReportEdit').getFields();
            }
            return expenseReportEditFieldSet;
        }
        set;
    }

    //Constructor ==============================================================
    public ExpenseReportControllerExt(ApexPages.StandardController controller) {
        try {
            // Querying the expense report and it's related expense lines
            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            isEmployeeError = false;
            isNameError = false;
            isReportDateError = false;
            isStatusError = false;
            isError = false;
            isExpenseInserted = false;
            ccVendorList = new List<SelectOption>();
            expenseRowNum = 0;
            mileageRowNum = 0;

            try {
                ccVendorList.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));

                for (Account acct : ExpenseReportHelper.queryCreditCardVendors()) {
                    ccVendorList.add(new SelectOption(acct.Id, acct.Name));
                }

                expReport = ExpenseReportHelper.queryExpenseReport(controller.getId());
                isExpenseInserted = true;
            }
            catch (Exception ex) {
                expReport = new Expense_Report__c();
                isExpenseInserted = false;
                expReport.Employee__c = UserInfo.getUserId();
                Ledger__c defaultLedger = LedgerHandler.getInstanceWithSharing().getLedgerById(LedgerHandler.getLedgerId());
                expReport.Ledger__c = (defaultLedger != NULL) ? defaultLedger.Id : NULL;
            }

            currencyIsoCode = isMultiCurrencyEnabled ? (String) expReport.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;

            for (Schema.PicklistEntry pe : Expense_Report__c.Status__c.getDescribe().getPicklistValues()) {
                if (expReport.Status__c == NULL && pe.isDefaultValue()) {
                    expReport.Status__c = pe.getValue();
                }
            }

            isExpenseError = false;
            isMileageError = false;
            
            expensesMap = new Map<Integer, ExpenseLineWrapper>();
            mileageMap = new Map<Integer, ExpenseLineWrapper>();

            removedRowsList = new List<Expense_Line__c>();
            
            expenseTypesList = new List<SelectOption>();

            mileageTypesList = new List<SelectOption>();
            
            expenseTypesList.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
            mileageTypesList.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
            
            expenseTypesMap = new Map<Id, GL_Account__c>();
             
            for (GL_Account__c objExpType : ExpenseReportHelper.queryGlAccounts()) {
                expenseTypesMap.put(objExpType.Id, objExpType);
                // Mileage GL Accounts : for Mileage tab expense types
                if (objExpType.Mileage_Account__c) {
                    if (objExpType.Expense_Report_Name__c != NULL) {
                        mileageTypesList.add(new SelectOption(objExpType.Id, objExpType.Expense_Report_Name__c));
                    }
                    else {
                        mileageTypesList.add(new SelectOption(objExpType.Id, objExpType.Name));
                    }
                }
                // Non Mileage GL Accounts : for Project and Non Project expense tabs
                else {
                    if (objExpType.Expense_Report_Name__c != NULL) {                
                        expenseTypesList.add(new SelectOption(objExpType.Id, objExpType.Expense_Report_Name__c));
                    }
                    else {                
                        expenseTypesList.add(new SelectOption(objExpType.Id, objExpType.Name));
                    }
                }
            }
            
            // Pre- populating existing expense lines related to the expense report
            if (expReport.Expense_Lines__r.size() > 0) {
            
                Map<Id, List<SelectOption>> projectTaskMap = new Map<Id, List<SelectOption>>();
                for (Expense_Line__c expenseLine : ExpenseReportHelper.queryExpenseLines(expReport.Id)) {
                    projectTaskMap.put(expenseLine.Project__c, new List<SelectOption>{new SelectOption('', '--' + Label.COMMON_NONE + '--')});
                }
        
                for (Project_Task__c theTask : FinancialSuiteUtils.queryProjectTasks(projectTaskMap.keySet())) {
                    projectTaskMap.get(theTask.Project__c).add(new SelectOption(theTask.Id,theTask.Name));
                }
                 
                for (Expense_Line__c expenseLine : expReport.Expense_Lines__r) {
                    ExpenseLineWrapper objWrapper = new ExpenseLineWrapper(expenseLine, expenseTypesMap, projectTaskMap.get(expenseLine.Project__c));
                    objWrapper.ccVendorId = expenseLine.Credit_Card_Vendor__c;

                    if (expenseTypesMap.containsKey(expenseLine.Expense_GL_Account__c)) {
                        objWrapper.strExpenseTypeId = expenseTypesMap.get(expenseLine.Expense_GL_Account__c).Id;
                    }

                    if (expenseLine.Miles__c == NULL) {               
                        objWrapper.intRowNum = expenseRowNum++;
                        expensesMap.put(objWrapper.intRowNum, objWrapper);
                    }
                    else if (expenseLine.Miles__c != NULL) {
                        objWrapper.intRowNum = mileageRowNum++;
                        mileageMap.put(objWrapper.intRowNum, objWrapper);
                        
                    }
                }
            }
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }
    }

    public String getLedgerIsoCode() {
        String result = MultiCurrencyHandler.CORPORATE_CURRENCY;
        if (isMultiCurrencyEnabled && expReport.Ledger__c != NULL) {
            result = (String) LedgerHandler.getInstanceWithoutSharing().getLedgerById(expReport.Ledger__c).get('CurrencyIsoCode');
        }
        return result;
    }

    public List<SelectOption> getAllLedgers() {
        return LedgerHandler.getInstanceWithSharing().getTransactionalLedgerSelectOptions();
    }

    public Decimal getProjectAmountTotal() {
        Decimal total = 0;
        
        for (ExpenseLineWrapper elw : expensesMap.values()) {
            if (elw.expenseLine.Amount__c != NULL) {
                total += elw.expenseLine.Amount__c;
            }
        }
        
        return total;
    }
    
    public Integer getMileageMilesTotal() {
        Integer total = 0;
        
        for (ExpenseLineWrapper elw : mileageMap.values()) {
            if (elw.expenseLine.Miles__c != NULL) {
                total += elw.expenseLine.Miles__c.intValue();
            }
        }
        
        return total;
    }  

    public Decimal getMileageAmountTotal() {
        Decimal total = 0;
        
        for (ExpenseLineWrapper elw : mileageMap.values()) {
            total += elw.getAmount();
        }
        
        return total;
    }

    // Method to handle deletion of a expense line from tab 1 : Project Expenses
    public void deleteExpenseLine() {
        // If it is an actual record then adding to a list of records to be deleted
        if (expensesMap.get(selectedExpenseRow).expenseLine.Id != NULL) {
            removedRowsList.add(expensesMap.get(selectedExpenseRow).expenseLine);
        }

        expensesMap.remove(selectedExpenseRow);
    }

    // Method to handle deletion of a expense line from tab 3 : Mileage Expenses
    public void deleteMileageLine() {
        if (mileageMap.get(selectedMileageRow).expenseLine.Id != NULL) {
            removedRowsList.add(mileageMap.get(selectedMileageRow).expenseLine);
        }

        mileageMap.remove(selectedMileageRow);
    }
    
    // Method to handle addition of a expense line to tab 1 : Project Expenses
    public void addExpenseLine() {
        Expense_Line__c expLine = new Expense_Line__c(Expense_Report__c = expReport.Id);
        if (isMultiCurrencyEnabled) {
            expLine.put('CurrencyIsoCode',(String)expReport.get('CurrencyIsoCode'));
        }
        ExpenseLineWrapper objWrapper = new ExpenseLineWrapper(
            expLine,
            expenseTypesMap,
            new List<SelectOption>{new SelectOption('', '--' + Label.COMMON_NONE + '--')}
        );
        objWrapper.intRowNum = expenseRowNum++;
        expensesMap.put(objWrapper.intRowNum, objWrapper);
    }

    // Method to handle addition of a expense line to tab 3 : Mileage Expenses
    public void addMileageLine() {
        ExpenseLineWrapper objWrapper = new ExpenseLineWrapper(
            new Expense_Line__c(Expense_Report__c = expReport.Id),
            expenseTypesMap,
            new List<SelectOption>{new SelectOption('', '--' + Label.COMMON_NONE + '--')}
        );
        objWrapper.intRowNum = mileageRowNum++;
        mileageMap.put(objWrapper.intRowNum, objWrapper);
    }
    
    public List<ExpenseLineWrapper> getExpensesList() {
        return expensesMap.values();
    }

    public List<ExpenseLineWrapper> getMileageList() {
        return mileageMap.values();
    }
        
    public PageReference saveAndClose() {
        try {
            saveExpenseReport();
            if (!isExpenseError && !isMileageError && !isEmployeeError && !isNameError && !isReportDateError && !isStatusError && !isReimburseAndCCVendorError) {
                return (new PageReference('/' + expReport.Id));
            }
        }
        catch (Exception ex) {
            
        }     
        return NULL;
    }
    
    public PageReference saveAndRefresh() {
        try {
            saveExpenseReport();
        }
        catch (Exception ex) {
            
        }    
         
        return NULL;        
    }
    
    private void saveExpenseReport() {
        isExpenseError = false;
        isMileageError = false;
        isEmployeeError = false;
        isNameError = false;
        isReportDateError = false;
        isStatusError = false;
        isReimburseAndCCVendorError = false;

        Savepoint sp = Database.setSavepoint();
        try {
            if (expReport.Name == NULL) {
                isNameError = true;
            }

            if (expReport.Employee__c == NULL) {
                isEmployeeError = true;
            }

            if (expReport.Status__c == NULL) {
                isStatusError = true;
            }
            /*
            if (isMultiCurrencyEnabled) {
                expReport.put('CurrencyIsoCode', getLedgerIsoCode());
            }
            */
            List<Expense_Line__c> expensesListUpsert = new List<Expense_Line__c>();
    
            // Project Expenses
            for (ExpenseLineWrapper elw : expensesMap.values()) {
                
                elw.isProjectError = false;
                elw.isProjectTaskError = false;
                elw.isAmountError = false;
                elw.isDateError = false;
                elw.isExpenseTypeError = false;
                elw.isReimburseAndCCVendorError = false;
                isReimburseAndCCVendorError = false;

                if (elw.expenseLine.Project__c == NULL) {
                    elw.isProjectError = true;
                    isExpenseError = true;              
                }
    
                if (elw.expenseLine.Project_Task__c == NULL) {
                    elw.isProjectTaskError = true;
                    isExpenseError = true;                
                }
                                     
                if (elw.expenseLine.Amount__c == NULL) {
                    elw.isAmountError = true;
                    isExpenseError = true;
                }

                if (elw.expenseLine.Date__c == NULL) {
                    elw.isDateError = true;
                    isExpenseError = true;
                }
    
                if (elw.strExpenseTypeId == NULL) {
                    elw.isExpenseTypeError = true;
                    isExpenseError = true;
                }

                if (isMultiCurrencyEnabled) {
                    elw.expenseLine.put('CurrencyIsoCode', getLedgerIsoCode());
                }

                if (expenseTypesMap.containsKey(elw.strExpenseTypeId)) {            
                    elw.expenseLine.Expense_GL_Account__c = (Id) elw.strExpenseTypeId;
                }
                
                elw.expenseLine.Credit_Card_Vendor__c = (Id) elw.ccVendorId;
                if (elw.expenseLine.Employee_Reimburse__c && elw.expenseLine.Credit_Card_Vendor__c != NULL) {
                    elw.isReimburseAndCCVendorError = true;
                    isReimburseAndCCVendorError = true;
                }
                
                expensesListUpsert.add(elw.expenseLine);
            }
    
            // Mileage Expenses
            for (ExpenseLineWrapper elw : mileageMap.values()) {
    
                elw.isProjectError = false;
                elw.isProjectTaskError = false;
                elw.isDateError = false;
                elw.isExpenseTypeError = false;
                elw.isOriginError = false;
                elw.isDestinationError = false;
                elw.isMilesError = false;
                elw.isMilesNegativeError = false;
                
                if (elw.expenseLine.Project__c == NULL) {
                    elw.isProjectError = true;
                    isMileageError = true;              
                }
    
                if (elw.expenseLine.Project_Task__c == NULL) {
                    elw.isProjectTaskError = true;
                    isMileageError = true;                
                }
                
                if (elw.expenseLine.Date__c == NULL) {
                    elw.isDateError = true;
                    isMileageError = true;
                }
    
                if (elw.strExpenseTypeId == NULL) {
                    elw.isExpenseTypeError = true;
                    isMileageError = true;
                }
    
                if (elw.expenseLine.Mileage_Origin__c == NULL) {
                    elw.isOriginError = true;
                    isMileageError = true;
                }
    
                if (elw.expenseLine.Mileage_Destination__c == NULL) {
                    elw.isDestinationError = true;
                    isMileageError = true;
                }
    
                if (elw.expenseLine.Miles__c == NULL) {
                    elw.isMilesError = true;
                    isMileageError = true;
                }
                
                if (elw.expenseLine.Miles__c != NULL && elw.expenseLine.Miles__c < 0) {
                    elw.isMilesNegativeError = true;
                    isMileageError = true;
                }

                if (isMultiCurrencyEnabled) {
                    elw.expenseLine.put('CurrencyIsoCode', getLedgerIsoCode());
                }

                if (expenseTypesMap.containsKey(elw.strExpenseTypeId)) {            
                    elw.expenseLine.Expense_GL_Account__c = (Id) elw.strExpenseTypeId;
                }
                 
                expensesListUpsert.add(elw.expenseLine);
            }

            if (isExpenseError) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    Label.ERR_EXPENSES_TAB_FILL_REQUIRED_FIELDS_EXPENSE_LINES
                ));
            }

            if (isMileageError) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    Label.ERR_MILEAGE_TAB_FILL_REQUIRED_FIELDS_MILEAGE_LINES
                ));
            }

            if (!isExpenseError
                    && !isMileageError
                    && !isEmployeeError
                    && !isNameError
                    && !isReportDateError
                    && !isStatusError
                    && !isReimburseAndCCVendorError) {

                if (expReport.Id != NULL) {
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(expReport, new List<String>{
                        'Employee__c',
                        'Status__c'
                    });
                }
                else {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(expReport, new List<String>{
                        'Employee__c',
                        'Status__c'
                    });
                }
                
                for (Expense_Line__c el : expensesListUpsert) {
                    if (el.Expense_Report__c == NULL || !isExpenseInserted) {
                        el.Expense_Report__c = expReport.Id;
                    }
                }

                SFDCSecurityUtils.upsertProxy(expensesListUpsert);
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(removedRowsList);
                removedRowsList.clear();
                isExpenseInserted = true;
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
            Database.rollback(sp);
            if (!isExpenseInserted) {
                expReport.Id = NULL;
            }
            throw ex;
        }
    }


    // Wrapper class for each line item =============================================================
    //===============================================================================================
    public class ExpenseLineWrapper {
        private Map<Id, GL_Account__c> glAccounts;
        private List<SelectOption> currentProjectTasks;
        private Id currentProject;

        public Expense_Line__c expenseLine {get; set;}
        public Integer intRowNum {get; set;}
        public String strExpenseTypeId {get; set;}
        public String ccVendorId {get; set;}

        public Boolean isProjectError {get; set;}
        public Boolean isProjectTaskError {get; set;}
        public Boolean isDateError {get; set;}
        public Boolean isAmountError {get; set;}
        public Boolean isExpenseTypeError {get; set;}
        public Boolean isOriginError {get; set;}
        public Boolean isDestinationError {get; set;}
        public Boolean isMilesError {get; set;}
        public Boolean isMilesNegativeError {get; set;}
        public Boolean isReimburseAndCCVendorError {get; set;}

        public ExpenseLineWrapper(Expense_Line__c expenseLine, Map<Id, GL_Account__c> glAccounts, List<SelectOption> currentProjectTasks) {
            this.expenseLine = expenseLine;
            this.currentProjectTasks = currentProjectTasks;
            currentProject = expenseLine.Project__c;
            isDateError = false;
            isAmountError = false;
            isExpenseTypeError = false;
            isOriginError = false;
            isDestinationError = false;
            isMilesError = false;
            isMilesNegativeError = false;
            isProjectError = false;
            isProjectTaskError = false;
            isReimburseAndCCVendorError = false;
            this.glAccounts = glAccounts;
        }

        public List<SelectOption> getProjectTasks() {
            if (expenseLine.Project__c == currentProject) {
                return currentProjectTasks;
            }

            currentProjectTasks = new List<SelectOption>{new SelectOption('', '--' + Label.COMMON_NONE + '--')};
            try {
                for (Project_Task__c theTask : queryProjectTasks(expenseLine.Project__c)) {
                    currentProjectTasks.add(new SelectOption(theTask.Id, theTask.Name));
                }

                currentProject = expenseLine.Project__c;
            }
            catch (Exception ex) {
                ApexPages.addMessages(ex);
            }
            return currentProjectTasks;
        }

        public Decimal getAmount() {
            Decimal total = 0;
            if (expenseLine != NULL
                && strExpenseTypeId != NULL
                && expenseLine.Miles__c != NULL
                && glAccounts.containsKey(strExpenseTypeId)
                && glAccounts.get(strExpenseTypeId).Mileage_Rate__c != NULL) {

                total = glAccounts.get(strExpenseTypeId).Mileage_Rate__c * expenseLine.Miles__c;
            }
            expenseLine.Amount__c = total;
            return total;
        }

        private List<Project_Task__c> queryProjectTasks(Id projectId) {
            //Prepare SOQL Query to query Project Tasks with CRUD and FLS checks
            List<String> queryFields = new List<String>{
                'Id',
                'Name'
            };

            String queryCondition = 'Project__c = :projectId AND Display_In_Time_Card__c = true ORDER BY Sort_Order__c ASC';

            SOQLBuilder theQuery = new SOQLBuilder(Project_Task__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);
            //============================================================================
            return (List<Project_Task__c>) Database.query(theQuery.toSOQL());
        }

    }


}