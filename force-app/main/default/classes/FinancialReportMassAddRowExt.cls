public with sharing class FinancialReportMassAddRowExt {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    /* private properties */
    private ApexPages.StandardSetController controller;
    private Id reportDefinitionId;
    private final List<String> GL_ACCOUNT_FIELDS = new List<String> {
        'Id', 'Name', 'Type__c', 'Sub_Type_1__c',
        'Sub_Type_2__c', 'Bank__c', 'Active__c'
    };
    private final Map<Integer, String> REPORT_TYPES_AVAILABLE_TO_SELECT = new Map<Integer, String>{
        0 => 'All',
        1 => 'Balance Sheet',
        2 => 'Profit & Loss'
    };

    /* public properties */
    public Financial_Report_Definition__c reportDefinition { get; private set; }
    public Financial_Report_Row__c proxyRow { get; set; }
    public Boolean reportIsInvalid { get; private set; }
    public Integer beginningRowNumber { get; set; }
    public Integer incrementRowNumber { get; set; }
    public Boolean activeFilter { get; set; }
    public Map<Id, GLAccountWrapper> glAccountWraps { get; set; }
    public Integer resultSize {
        get {
            Integer size = 0;
            if (glAccountWraps != NULL) {
                size = glAccountWraps.size();
            }
            return size;
        }
    }
    public String mode { get; set; }
    public List<SelectOption> reportTypes {
        get {
            if (reportTypes == NULL) {
                reportTypes = new List<SelectOption>();
                for (Integer rTypeKey : REPORT_TYPES_AVAILABLE_TO_SELECT.keySet()) {
                    SelectOption tempOption =
                        new SelectOption(
                            String.valueOf(rTypeKey),
                            REPORT_TYPES_AVAILABLE_TO_SELECT.get(rTypeKey)
                        );

                    reportTypes.add(tempOption);
                }
            }
            return reportTypes;
        }
        set;
    }
    public String selectedReportType { get; set; }
    public Boolean groupBySubType1 { get; set; }
    public Boolean groupBySubType2 { get; set; }

    /* constructor */
    public FinancialReportMassAddRowExt(ApexPages.StandardSetController controller) {
        try {
            this.controller = controller;
            this.reportDefinitionId = ApexPages.currentPage().getParameters().get('id');
            this.reportIsInvalid = false;
            this.mode = 'Edit';
            this.selectedReportType = '0';
            groupBySubType1 = false;
            groupBySubType2 = false;

            if (this.reportDefinitionId == NULL) {
                throw new MassAddRowException(Label.ERR_ID_OF_REPORT_STATEMENT_REQ);
            }

            List<Financial_Report_Definition__c> reportDefs =
                queryFinancialReportDefinitionsById(new Set<Id>{this.reportDefinitionId});

            if (reportDefs.isEmpty()) {
                throw new MassAddRowException(Label.ERR_REPORT_DEFINITION_NOT_FOUND + ': ' + this.reportDefinitionId);
            }

            this.reportDefinition = reportDefs.get(0);

            if (!this.reportDefinition.Financial_Report_Rows__r.isEmpty()) {
                this.reportIsInvalid = true;
                addWarning(
                    Label.WRN_REPORT_DEFINITION_NOT_FOUND
                );
            }

            // set defaults
            this.proxyRow = new Financial_Report_Row__c();
            this.beginningRowNumber = 10;
            this.incrementRowNumber = 10;
            this.activeFilter = true;
            this.glAccountWraps = new Map<Id, GLAccountWrapper>();

            if (this.reportIsInvalid) return;

            // now call the gl account query
            this.queryGLAccounts();
        }
        catch (Exception ex) {
            addError(ex.getMessage());
        }
    }

    // Security Review Note: This class is a controller extension and the fields queried are exposed via Visualforce.
    // Hence, CRUD & FLS is handled by Visualforce page.
    private List<Financial_Report_Definition__c> queryFinancialReportDefinitionsById(Set<Id> frdIds) {
        List<String> queryFields = new List<String>{
            'Id', 'Name'
        };
        String queryCondition = 'Id IN :frdIds';

        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Financial_Report_Rows__r';

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Report_Definition__c.SObjectType);
        theQuery
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, false)
            .setLimit(1);

        return (List<Financial_Report_Definition__c>) Database.query(theQuery.toSOQL());
    }

    /* gl account query */
    public void queryGLAccounts() {
        try {
            this.glAccountWraps = new Map<Id, GLAccountWrapper>();
            List<String> rTypes = getGLAccountTypesBySelectedOnPage();

            List<String> queryFields = new List<String>();
            queryFields.addAll(GL_ACCOUNT_FIELDS);

            String queryCondition = '';
            if (rTypes == NULL) {
                queryCondition += 'Type__c != NULL ';
            }
            else {
                queryCondition += 'Type__c IN :rTypes ';
            }
            if (this.activeFilter) {
                queryCondition += 'AND Active__c = true ';
            }
            queryCondition += 'ORDER BY Type__c ASC';

            queryCondition +=
                (groupBySubType1 && (selectedReportType == '1' || selectedReportType == '2'))
                    ? ', Sub_Type_1__c ASC'
                    : '';

            queryCondition += (groupBySubType2 && (selectedReportType == '2')) ? ', Sub_Type_2__c ASC' : '';
            queryCondition += ', Name ASC';

            SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            for (GL_Account__c gla : (List<GL_Account__c>) Database.query(theQuery.toSOQL())) {
                this.glAccountWraps.put(gla.Id, new GlAccountWrapper(gla));
            }

            if ((selectedReportType == '1' || selectedReportType == '2') && (groupBySubType1 || groupBySubType2)) {
                sortPicklistNullLast();
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    private void sortPicklistNullLast() {
        if (this.glAccountWraps.isEmpty()) {
            return;
        }

        List<GlAccountWrapper> result = new List<GlAccountWrapper>();

        if (selectedReportType == '2') {//"Profit and Loss"

            List<GlAccountWrapper> glAccountSubtype1Null = new List<GlAccountWrapper>();
            List<GlAccountWrapper> glAccountSubtype2Null = new List<GlAccountWrapper>();
            String type = 'Revenue';
            String subType1 = NULL;
            String subType2 = NULL;
            /*
            ** Salesforce does not provide a means to sort picklists with nulls last. This code section sorts with nulls last
            ** if the subtype1 or subtype2 grouping is selected
            */
            for (GlAccountWrapper glAcct : this.glAccountWraps.values()) {

                if (groupBySubType1 && type != glAcct.glAccount.Type__c) {
                    type = glAcct.glAccount.Type__c;
                    result.addAll(glAccountSubtype1Null);
                    glAccountSubtype1Null.clear();
                }

                if (groupBySubType1 && (subType1 == NULL || subType1 != glAcct.glAccount.Sub_Type_1__c)) {
                    subType1 = glAcct.glAccount.Sub_Type_1__c;
                    result.addAll(glAccountSubtype2Null);
                    glAccountSubtype2Null.clear();
                }

                if (groupBySubType1 && glAcct.glAccount.Sub_Type_1__c == NULL) {
                    glAccountSubtype1Null.add(glAcct);
                }
                else if (groupBySubType2 && glAcct.glAccount.Sub_Type_2__c == NULL) {
                    glAccountSubtype2Null.add(glAcct);
                }
                else {
                    result.add(glAcct);
                }
            }

            result.addAll(glAccountSubtype1Null);
            result.addAll(glAccountSubtype2Null);
        }

        if (selectedReportType == '1') {//"Balance Sheet"
            List<GlAccountWrapper> glAccountSubtype2Null = new List<GlAccountWrapper>();
            String type = 'Assets';

            for (GlAccountWrapper glAcct : this.glAccountWraps.values()) {

                if (type != glAcct.glAccount.Sub_Type_1__c) {
                    type = glAcct.glAccount.Sub_Type_1__c;
                    result.addAll(glAccountSubtype2Null);
                    glAccountSubtype2Null.clear();
                }

                if (groupBySubType1 && glAcct.glAccount.Sub_Type_2__c == NULL) {
                    glAccountSubtype2Null.add(glAcct);
                }
                else {
                    result.add(glAcct);
                }
            }

            result.addAll(glAccountSubtype2Null);
        }

        this.glAccountWraps.clear();
        for (GlAccountWrapper wrappedGLAccount : result) {
            this.glAccountWraps.put(wrappedGLAccount.glAccount.Id, wrappedGLAccount);
        }

    }

    private List<String> getGLAccountTypesBySelectedOnPage() {
        List<String> result = new List<String>();
        if (selectedReportType == '1') {//means "Balance Sheet"
            result.add('Balance Sheet');
            return result;
        }
        else if (selectedReportType == '2') {//means "Profit and Loss"
            result.add('Revenue');
            result.add('Expense');
            return result;
        }
        else if (selectedReportType == '0') {//means All available types
            result.add('Balance Sheet');
            result.add('Revenue');
            result.add('Expense');
            return result;
        }
        return NULL;
    }

    public PageReference createRows() {

        if (this.reportIsInvalid) {
            addError(Label.ERR_CANNOT_CREATE_ROWS + ' ' + Label.WRN_REPORT_DEFINITION_NOT_FOUND);
            return NULL;
        }

        List<GL_Account__c> selectedGLAccounts = new List<GL_Account__c>();

        for (GLAccountWrapper glw : this.glAccountWraps.values()) {
            if (glw.selected) {
                selectedGLAccounts.add(glw.glAccount);
            }
        }

        if (selectedGLAccounts.isEmpty()) {
            addError(Label.ERR_NO_GL_ACCOUNT_SELECTED);
            return NULL;
        }

        List<Financial_Report_Row__c> rows = dispatchRowsCreation(selectedGLAccounts);

        try {
            SFDCSecurityUtils.insertCheckCRUDAndFLS(rows, new List<String>{
                'Position__c',
                'Indent__c',
                'Underline__c',
                'Type__c',
                'Calculation__c',
                'Row_Label__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Normal_Balance__c'
            });
        }
        catch (Exception e) {
            addError(Label.ERR_UNABLE_TO_INSERT_ROWS + ': ' + e.getMessage());
            return NULL;
        }

        PageReference ref = new PageReference('/' + this.reportDefinition.Id);
        ref.setRedirect(true);
        return ref;
    }

    private List<Financial_Report_Row__c> dispatchRowsCreation(List<GL_Account__c> selectedGLAccounts) {
        List<Financial_Report_Row__c> result;
        if (selectedReportType == '1' && groupBySubType1) {
            result = createGroupedBalanceSheetRows(selectedGLAccounts);
        }
        else if (selectedReportType == '2' && (groupBySubType1 || groupBySubType2)) {
            result = createGroupedProfitAndLossRows(selectedGLAccounts);
        }
        else {
            result = createRegularRows(selectedGLAccounts);
        }

        return result;
    }

    private List<Financial_Report_Row__c> createGroupedBalanceSheetRows(List<GL_Account__c> selectedGLAccounts) {
        List<Financial_Report_Row__c> result = new List<Financial_Report_Row__c>();

        Financial_Report_Row__c frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        Integer position = this.beginningRowNumber;
        Integer totalLiabilityRow = 0;
        Integer totalEquityRow = 0;
        String typeRowCalculation = '';

        String currentType = NULL;
        String subType1 = NULL;
        Integer indentSpaces = 0;
        Integer glAccountIndent = indentSpaces + 2;
        Integer subType1Indent = indentSpaces + 1;

        Integer subType1Count = 0;

        for (GL_Account__c glAccount : selectedGLAccounts) {
            String currentSubType1 = glAccount.Sub_Type_2__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_2__c;

            if (subType1 != currentSubType1 && subType1 != NULL) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent + 1);
                frr.Underline__c = 'Single';
                frr.Type__c = 'Calculation Number';
                frr.Calculation__c = '{r' + (position - (subType1Count * this.incrementRowNumber)) + ':r' + (position - this.incrementRowNumber) + '}';
                typeRowCalculation += '{r' + position + '}+';
                frr.Row_Label__c = 'Total ' + subType1;
                result.add(frr);
            }

            if (currentType == NULL) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                frr.Position__c = position;
                typeRowCalculation = '';
                frr.Type__c = 'Description';
                frr.Row_Label__c = glAccount.Sub_Type_1__c;
                result.add(frr);
                currentType = glAccount.Sub_Type_1__c;
            }

            if (currentType != glAccount.Sub_Type_1__c) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(indentSpaces);
                frr.Underline__c = currentType == 'Liabilities' ? 'Single' : 'Double';
                frr.Row_Label__c = 'Total ' + currentType;
                frr.Type__c = 'Calculation Number';
                frr.Calculation__c = typeRowCalculation.removeEnd('+');
                result.add(frr);

                totalLiabilityRow = currentType == 'Liabilities' ? position : 0;

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Type__c = 'Blank';
                result.add(frr);

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Type__c = 'Blank';
                result.add(frr);

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Type__c = 'Description';
                frr.Row_Label__c = glAccount.Sub_Type_1__c;
                result.add(frr);

                currentType = glAccount.Sub_Type_1__c;
                subType1 = NULL;
                typeRowCalculation = '';
            }

            if (subType1 != currentSubType1) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent);
                frr.Type__c = 'Description';
                frr.Row_Label__c = glAccount.Sub_Type_2__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_2__c;
                result.add(frr);
                subType1 = glAccount.Sub_Type_2__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_2__c;
                subType1Count = 0;
            }

            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
            position += this.incrementRowNumber;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(glAccountIndent);
            frr.GL_Account__c = glAccount.Id;
            frr.Type__c = 'GL Account';
            frr.GL_Account_Variable_1__c = this.proxyRow.GL_Account_Variable_1__c;
            frr.GL_Account_Variable_2__c = this.proxyRow.GL_Account_Variable_2__c;
            frr.GL_Account_Variable_3__c = this.proxyRow.GL_Account_Variable_3__c;
            frr.GL_Account_Variable_4__c = this.proxyRow.GL_Account_Variable_4__c;
            frr.Row_Label__c = glAccount.Name;
            if (glAccount.Sub_Type_1__c == 'Assets') {
                frr.Normal_Balance__c = 'Debit';
            }
            else {
                frr.Normal_Balance__c = 'Credit';
            }

            result.add(frr);
            subType1Count++;
        }

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        position += this.incrementRowNumber;
        frr.Position__c = position;
        frr.Indent__c = String.valueOf(subType1Indent + 1);
        frr.Underline__c = 'Single';
        frr.Type__c = 'Calculation Number';
        frr.Calculation__c = '{r' + (position-(subType1Count * this.incrementRowNumber)) + ':r' + (position - this.incrementRowNumber) + '}';
        typeRowCalculation += '{r' + position + '}+';
        frr.Row_Label__c = 'Total ' + subType1;
        result.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        position += this.incrementRowNumber;
        frr.Position__c = position;
        frr.Indent__c = String.valueOf(indentSpaces);
        frr.Underline__c = 'Single';
        frr.Row_Label__c = 'Total ' + currentType;
        frr.Type__c = 'Calculation Number';
        totalEquityRow = currentType == 'Owners Equity' ? position : 0;
        frr.Calculation__c = typeRowCalculation.removeEnd('+');
        result.add(frr);

        return result;
    }

    private List<Financial_Report_Row__c> createGroupedProfitAndLossRows(List<GL_Account__c> selectedGLAccounts) {

        List<Financial_Report_Row__c> result = new List<Financial_Report_Row__c>();
        String type = 'Revenue';
        String subType1 = NULL;
        String subType2 = NULL;

        String currentType = 'Revenue';

        Financial_Report_Row__c frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        Integer position = this.beginningRowNumber;
        Integer totalRevenueRow = 0;
        Integer totalExpenseRow = 0;

        frr.Position__c = position;
        frr.Type__c = 'Description';
        frr.Row_Label__c = 'Revenue';
        result.add(frr);

        subType1 = NULL;
        Integer indentSpaces = 0;
        Integer glAccountIndent = indentSpaces + 1;
        Integer subType1Indent = indentSpaces + 1;
        Integer subType2Indent = subType1Indent + 1;

        glAccountIndent += (groupBySubtype1 ? subType1Indent : 0);
        glAccountIndent += (groupBySubtype2 ? subType2Indent : 0);

        Integer subType1Count = 0;

        subType2 = NULL;
        Integer subType2Count = 0;
        String calculationTotal = '';
        String calculationSubType1 = '';
        String calculationSubType2 = '';
        Integer startExpensePosition;

        for (GL_Account__c glAccount : selectedGLAccounts) {

            String currentSubType1 = glAccount.Sub_Type_1__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_1__c;
            String currentSubType2 = glAccount.Sub_Type_2__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_2__c;

            if (subType2 != currentSubType2 && subType2 != NULL && groupBySubType2) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType2Indent + 1);
                frr.Underline__c = 'Single';
                frr.Type__c = 'Calculation Number';
                frr.Calculation__c = calculationSubType2.removeEnd('+');
                calculationSubType2 = '';
                frr.Row_Label__c = 'Total ' + subType2;
                result.add(frr);
            }

            if (subType1 != currentSubType1 && subType1 != NULL && groupBySubtype1) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent + 1);
                frr.Underline__c = 'Single';
                frr.Type__c = 'Calculation Number';
                frr.Calculation__c = calculationSubType1.removeEnd('+');
                calculationTotal += '{r' + position + '}+';
                calculationSubType1 = '';
                frr.Row_Label__c = 'Total ' + subType1;
                result.add(frr);
            }

            if (currentType != glAccount.Type__c) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);

                position += this.incrementRowNumber;
                frr.Position__c = totalRevenueRow = position;
                frr.Indent__c = String.valueOf(indentSpaces);
                frr.Underline__c = 'Single';
                frr.Row_Label__c = 'Total Revenue';
                frr.Type__c = 'Calculation Number';
                frr.Calculation__c = groupBySubtype1 ? calculationTotal.removeEnd('+') : '{r20:r' + (position-10) + '}';
                calculationTotal = calculationSubType1 = calculationSubType2 = '';
                result.add(frr);
                currentType = 'Expense';

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Type__c = 'Blank';
                result.add(frr);

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Type__c = 'Blank';
                result.add(frr);

                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Type__c = 'Description';
                frr.Row_Label__c = 'Expense';
                result.add(frr);
                subType1 = NULL;
                subType2 = NULL;

                startExpensePosition = position + this.incrementRowNumber;
            }

            if (subType1 != currentSubType1 && groupBySubtype1) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType1Indent);
                frr.Type__c = 'Description';
                frr.Row_Label__c = glAccount.Sub_Type_1__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_1__c;
                result.add(frr);
                subType1 = glAccount.Sub_Type_1__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_1__c;
                subType1Count = 0;
            }

            if (subType2 != currentSubType2 && groupBySubtype2) {
                frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
                position += this.incrementRowNumber;
                frr.Position__c = position;
                frr.Indent__c = String.valueOf(subType2Indent);
                frr.Type__c = 'Description';
                frr.Row_Label__c = glAccount.Sub_Type_2__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_2__c;
                result.add(frr);
                subType2 = glAccount.Sub_Type_2__c == NULL ? 'Uncategorized' : glAccount.Sub_Type_2__c;
                subType2Count = 0;
            }

            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
            position += this.incrementRowNumber;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(glAccountIndent);
            frr.GL_Account__c = glAccount.Id;
            frr.GL_Account_Variable_1__c = this.proxyRow.GL_Account_Variable_1__c;
            frr.GL_Account_Variable_2__c = this.proxyRow.GL_Account_Variable_2__c;
            frr.GL_Account_Variable_3__c = this.proxyRow.GL_Account_Variable_3__c;
            frr.GL_Account_Variable_4__c = this.proxyRow.GL_Account_Variable_4__c;
            frr.Type__c = 'GL Account';
            frr.Row_Label__c = glAccount.Name;
            frr.Normal_Balance__c = currentType == 'Revenue' ? 'Credit' : 'Debit';

            calculationSubType1 += '{r' + position + '}+';
            calculationSubType2 += '{r' + position + '}+';
            result.add(frr);
            subType1Count++;
            subType2Count++;
        }

        if (groupBySubtype2) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
            position += this.incrementRowNumber;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(subType2Indent + 1);
            frr.Underline__c = 'Single';
            frr.Type__c = 'Calculation Number';
            frr.Calculation__c = calculationSubType2.removeEnd('+');
            frr.Row_Label__c = 'Total ' + subType2;
            result.add(frr);
        }

        if (groupBySubtype1) {
            frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
            position += this.incrementRowNumber;
            frr.Position__c = position;
            frr.Indent__c = String.valueOf(subType1Indent + 1);
            frr.Underline__c = 'Single';
            frr.Type__c = 'Calculation Number';
            frr.Calculation__c = calculationSubType1.removeEnd('+');
            calculationTotal += '{r' + position + '}+';
            frr.Row_Label__c = 'Total ' + subType1;
            result.add(frr);
        }

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        position += this.incrementRowNumber;
        frr.Position__c = totalExpenseRow = position;
        frr.Indent__c = String.valueOf(indentSpaces);
        frr.Underline__c = 'Single';
        frr.Row_Label__c = 'Total Expense';
        frr.Type__c = 'Calculation Number';
        frr.Calculation__c = groupBySubtype1 ? calculationTotal.removeEnd('+') : '{r' + startExpensePosition + ':r' + (position-10) + '}';
        result.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        position += this.incrementRowNumber;
        frr.Position__c = position;
        frr.Type__c = 'Blank';
        result.add(frr);

        frr = new Financial_Report_Row__c(Financial_Report_Definition__c = this.reportDefinition.Id);
        position += this.incrementRowNumber;
        frr.Position__c = totalExpenseRow = position;
        frr.Underline__c = 'Double';
        frr.Row_Label__c = 'Net Income';
        frr.Type__c = 'Calculation Number';
        frr.Calculation__c = '{r' + totalRevenueRow + '}-{r' + (totalExpenseRow-20) + '}';
        result.add(frr);
        currentType = 'Expense';

        return result;
    }

    private List<Financial_Report_Row__c> createRegularRows(List<GL_Account__c> selectedGLAccounts) {
        List<Financial_Report_Row__c> result = new List<Financial_Report_Row__c>();

        Integer currentRowNumber = this.beginningRowNumber;

        for (GL_Account__c glAccount : selectedGLAccounts) {
            Financial_Report_Row__c row = new Financial_Report_Row__c();
            row.Financial_Report_Definition__c = this.reportDefinition.Id;
            row.Row_Label__c = glAccount.Name;
            row.Type__c = 'GL Account';
            row.GL_Account__c = glAccount.Id;
            row.GL_Account_Variable_1__c = this.proxyRow.GL_Account_Variable_1__c;
            row.GL_Account_Variable_2__c = this.proxyRow.GL_Account_Variable_2__c;
            row.GL_Account_Variable_3__c = this.proxyRow.GL_Account_Variable_3__c;
            row.GL_Account_Variable_4__c = this.proxyRow.GL_Account_Variable_4__c;
            row.Position__c = currentRowNumber;
            if (glAccount.Type__c == 'Balance Sheet' || glAccount.Type__c == 'Expense') {
                row.Normal_Balance__c = 'Debit';
            }
            else {
                row.Normal_Balance__c = 'Credit';
            }
            result.add(row);
            currentRowNumber += incrementRowNumber;
        }

        return result;
    }

    public PageReference cancel() {
        PageReference ref = new PageReference('/' + this.reportDefinition.Id);
        ref.setRedirect(true);
        return ref;
    }

    @TestVisible
    private void addInfo(String message) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.INFO, message));
    }

    @TestVisible
    private void addWarning(String message) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, message));
    }

    @TestVisible
    private void addError(String message) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, message));
    }

    public with sharing class GlAccountWrapper {
        public GL_Account__c glAccount { get; set; }
        public Boolean selected { get; set; }

        public GLAccountWrapper(GL_Account__c glAccount) {
            this.glAccount = glAccount;
            this.selected = false;
        }
    }

    public class MassAddRowException extends Exception {}

}