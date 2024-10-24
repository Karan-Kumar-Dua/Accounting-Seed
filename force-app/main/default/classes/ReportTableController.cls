public with sharing class ReportTableController {

    private static Set<String> RESERVED_HEADERS = new Set<String>{
        'period-budget-column',
        'calculated-budget-column'
    };

    private final Financial_Report_Result__c frr;

    private transient FinancialReportWrapper frwValue;
    private Financial_Report_Definition__c reportDef;
    private Map<Integer, String> acctPeriodMap;
    private Map<string, Accounting_Period__c> accountingPeriodByOffsetMap;
    private Integer decimalPlaces;

    public transient Financial_Report_Result__c report {get; private set;}
    public transient List<ReportRow> reportValueRows {get; private set;}
    public FinancialReportWrapper frw {
        get;        
        set {
            frwValue = value;
            initReportValueRows();
            initReportSettings();
            initHeaders();
            initHeaders2();
        }
    }
    public String theReportName {get; set;}
    public String theReportSubtitle {get; set;}
    public String currentPeriodName {get; set;}
    public String startPeriodName {get; set;}
    public String endPeriodName {get; set;}
    public Financial_Report_Row__c theReportRow {get; set;}
    public List<String> headers {get; private set;}
    public List<String> headers2 {get; private set;}
    public Boolean isPDF {get; set;}
    public Boolean isXLS {get; set;}
    public Accounting_Variable__c GLVariable1 {get; set;}
    public Accounting_Variable__c GLVariable2 {get; set;}
    public Accounting_Variable__c GLVariable3 {get; set;}
    public Accounting_Variable__c GLVariable4 {get; set;}
    public Ledger__c ledger {get; set;}
    public Ledger__c budgetLedger {get; set;}
    public Financial_Report_Result__c reportResult {get; set;}
    public String reportTime {get; set;}
    public Boolean isCustomReport {get; set;}
    public Boolean isNeedSmallFont {get; set;}
    public String defaultCurrency {get; set;}
    public String companyName {get; set;}
    public String companyLogo {get; set;}
    public String columnHeaderVariant {get; set;}
    public String roundedTo {get; set;}

    private void initReportSettings() {
        if (ledger != null) {
            FinancialReporterSettingsHandler.FinancialReporterSettings frs =
                FinancialReporterSettingsHandler.getInstance().getSettings(ledger.Id);
            companyName = frs?.settings?.Company_Name__c;
            companyLogo = frs?.companyLogoId == null ? null : '/sfc/servlet.shepherd/version/download/' + frs.companyLogoId;
            columnHeaderVariant = frs?.settings?.Column_Header_Variant__c;
        }
    }

    private void initHeaders() {
        headers = new List<String>();
        
        if (frwValue != null && frwValue.reportvalues != null && frwValue.reportvalues.size() > 0) {
            Map<Integer, String> head1Map = new Map<Integer, String>();
            
            for (Financial_Report_Result_Value__c frv : frwValue.reportvalues) {

               //Experimental
                if (!frv.Suppress_Print__c) {
                    string columnHeader = isCustomReport ? frv.Column_Header_1__c : getColumnHeaderText(frv.Column_Header_1__c, frv.Column_Type__c);
                    head1Map.put(frv.Column_Position__c.intValue(), columnHeader);
                }
                if (frv.Financial_Report_Result__c != NULL && reportResult == NULL) {
                    reportResult = DomainUtils.getFinancialReportResultsById(new Set<Id> {frv.Financial_Report_Result__c})[0];
                    reportTime = reportResult.Run_Finished__c.format();

                    switch on reportResult.Rounding__c {
                        when 'Round to 1000s' {
                            roundedTo = 'Rounded to 1000s';
                        }
                        when 'Whole Amounts' {
                            roundedTo = 'Rounded to Whole Amounts';
                        }
                        when else {
                            roundedTo = '';
                        }
                    }
                }
            }

            List<Integer> colInts = new List<Integer>();
            
            //Experimental
            for (Integer i : head1Map.keyset()) {
                colInts.add(i);
            }
            
            colInts.sort();
            
            //Experimental
            for (Integer i : colInts) {
                if (head1Map.get(i) == null) {
                    headers.add(' ');
                } 
                else {
                    headers.add(head1Map.get(i));
                }
            }
            isNeedSmallFont = headers.size() >= 10 ? true : false;
        }
    }
    
    private void initHeaders2() {
        headers2 = new List<String>();
        
        if (frwValue != null && frwValue != null && frwValue.reportvalues != null && frwValue.reportvalues.size() > 0) {
            Map<Integer, String> head2Map = new Map<Integer, String>();
            
            for (Financial_Report_Result_Value__c frv : frwValue.reportvalues) {
               //Experimental
               if (!frv.Suppress_Print__c && !RESERVED_HEADERS.contains(frv.Column_Header_2__c)) {
                   if(frv.Column_Header_2__c != null){
                        string columnHeader2 = isCustomReport ? frv.Column_Header_2__c : getColumnHeaderText(frv.Column_Header_2__c, frv.Column_Type__c);
                        head2Map.put(frv.Column_Position__c.intValue(), columnHeader2);
                   }else{
                        head2Map.put(frv.Column_Position__c.intValue(), frv.Column_Header_2__c);
                   }

               }
            }
            
            List<Integer> colInts = new List<Integer>();
            
            //Experimental
            for (Integer i : head2Map.keyset()) {
               colInts.add(i);
            }
            
            colInts.sort();
            
            //Experimental
            for (Integer i : colInts) {
                if (head2Map.get(i) == null) {
                    headers2.add(' ');
                } 
                else {
                    headers2.add(head2Map.get(i));
                }
            }
            isNeedSmallFont = headers2.size() >= 10 ? true : false;
        }
    }
    
    private void initReportValueRows() {

        isCustomReport = false;
        reportValueRows = new List<ReportRow>();
        if (frwValue != NULL && frwValue.reportDefinition != NULL) {
            if (frwValue.reportDefinition.Id != NULL
                    && !DomainUtils.getFinancialReportDefinitionByName(new Set<String> {frwValue.reportDefinition.Name}).isEmpty()) {

                decimalPlaces = Integer.valueOf(DomainUtils.getFinancialReportDefinitionByName(new Set<String> {frwValue.reportDefinition.Name})[0].Percentage_Decimal_Places__c);
                isCustomReport = true;
            }
        }
        decimalPlaces = decimalPlaces != NULL ? decimalPlaces : 2;

        if (frwValue != NULL && frwValue.reportvalues != NULL && frwValue.reportvalues.size() > 0) {
            acctPeriodMap = new Map<Integer, String>();
            
            acctPeriodMap.put(0, currentPeriodName);

            if (frwValue.getLedgerId() != NULL) {
                ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(frwValue.getLedgerId());
            }

            if (frwValue.getBudgetLedgerId() != NULL) {
                budgetLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(frwValue.getBudgetLedgerId());
            }

            if (ledger != NULL) {
                defaultCurrency = MultiCurrencyHandler.isMultiCurrencyEnabled ?
                        (String) frwValue.reportResult.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            }

            Set<Id> glavsIds = new Set<Id>();
            glavsIds.add(frwValue.getGLVariable1Id());
            glavsIds.add(frwValue.getGLVariable2Id());
            glavsIds.add(frwValue.getGLVariable3Id());
            glavsIds.add(frwValue.getGLVariable4Id());

            List<Accounting_Variable__c> glavsList = DomainUtils.getGLAVsById(glavsIds);
            if (!glavsList.isEmpty()) {
                for (Accounting_Variable__c variable : glavsList) {
                    if (variable.Type__c == 'GL Account Variable 1') {
                        GLVariable1 = variable;
                    }
                    if (variable.Type__c == 'GL Account Variable 2') {
                        GLVariable2 = variable;
                    }
                    if (variable.Type__c == 'GL Account Variable 3') {
                        GLVariable3 = variable;
                    }
                    if (variable.Type__c == 'GL Account Variable 4') {
                        GLVariable4 = variable;
                    }
                }
            }

            for (Financial_Report_Column__c col : frwValue.colList) {
                String nextPeriodName = currentPeriodName;
                if (col.Type__c == 'Current Period' || col.Type__c == 'Year To Date') {
                    nextPeriodName = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriodName, Integer.valueOf(col.Offset__c)).Name;
                }
                acctPeriodMap.put(col.Position__c.intValue(), nextPeriodName);
            }

            accountingPeriodByOffsetMap = getAccountingPeriodByOffsetMap(frwValue.colList, currentPeriodName);

            Map<Integer, ReportRow> rowColMap = new Map<Integer, ReportRow>();

            Integer row;
            Integer col;

            Map<Integer, Id> rowPositionToGLAccountId = mapRowPositionToGLAccount(frwValue.rowList);
            Map<Integer, Financial_Report_Row__c> rowPositionToRowRecord = mapRowPositionToRowRecord(frwValue.rowList);

            for (Financial_Report_Result_Value__c frv : frwValue.reportvalues) {
                //avoid empty value within each cell
                if (frv.Currency_Value__c == NULL) {
                    frv.Currency_Value__c = 0;
                }

                row = frv.Row_Position__c.intValue();
                col = frv.Column_Position__c.intValue();
                String acctPeriodId = acctPeriodMap.get(col);

                ReportRow rowvalue;
            
                String textvalue = frv.Text_Value__c;

                if (frv.Text_Value__c == NULL) {
                    textvalue = String.valueOf(frv.Currency_Value__c);
                }

                Id glAccountId = rowPositionToGLAccountId.get(row);
                Map<String, Id> glavsMap = getGLAVFromReportRow(rowPositionToRowRecord.get(row));

                if (rowColMap.containsKey(row)){
                    rowvalue = rowColMap.get(row);
                    
                    if (frv.Row_Label__c == NULL) {
                        rowvalue.rowlabel = ' ';
                    }
                    else {
                        rowvalue.rowlabel = frv.Row_Label__c;
                    }

                    String rowType = frv.Row_Type__c.toLowerCase();
                    rowvalue.cssclass = 'indent-' + frv.Indent__c + rowType.deleteWhitespace();
                    rowvalue.rowIndent = (Integer) frv.Indent__c;

                    rowvalue.values.add(new ReportValue(frv, glAccountId, acctPeriodId, glavsMap, ledger.Id, decimalPlaces));
                    rowColMap.put(row, rowvalue);
                } 
                else {
                    rowvalue = new ReportRow();
                    
                    if (frv.Row_Label__c == NULL) {
                        rowvalue.rowlabel = ' ';
                    }
                    else {
                        rowvalue.rowlabel = frv.Row_Label__c;
                    }
                    String rowType = frv.Row_Type__c.toLowerCase();
                    rowvalue.cssclass = 'indent-' + frv.Indent__c + rowType.deleteWhitespace();
                    rowvalue.rowIndent = (Integer) frv.Indent__c;

                    rowvalue.values.add(new ReportValue(frv, glAccountId, acctPeriodId, glavsMap, ledger.Id, decimalPlaces));
                    rowColMap.put(row, rowvalue);
                }

            }
            
            List<Integer> rowNums = new List<Integer>();
            
            rowNums.addAll(rowColMap.keyset());
            rowNums.sort();
            
            for (Integer i : rowNums) {
                reportValueRows.add(rowColMap.get(i));
            }
            startPeriodName = theReportName == 'Trial Balance' ? acctPeriodMap.values().get(1) : acctPeriodMap.values().get(0);
            endPeriodName = returnEndPeriod();
        }
    }

    private String returnEndPeriod() {
        String result = '';
        for (String value : acctPeriodMap.values()) {
            if (value > result) {
                result = value;
            }
        }
        return result;
    }

    @TestVisible private Map<Integer, Financial_Report_Row__c> mapRowPositionToRowRecord(List<Financial_Report_Row__c> rowList) {
        Map<Integer, Financial_Report_Row__c> result = new Map<Integer, Financial_Report_Row__c>();
        for (Financial_Report_Row__c eachRow : rowList) {
            if (eachRow.Position__c != NULL) {
                result.put(eachRow.Position__c.intValue(), eachRow);
            }
        }
        return result;
    }

    @TestVisible private Map<Integer, Id> mapRowPositionToGLAccount(List<Financial_Report_Row__c> rowList) {
        Map<Integer, Id> result = new Map<Integer, Id>();
        for (Financial_Report_Row__c eachRow : rowList) {
            if (eachRow.Position__c != NULL && eachRow.GL_Account__c != NULL) {
                result.put(eachRow.Position__c.intValue(), eachRow.GL_Account__c);
            }
        }
        return result;
    }

    @TestVisible private Map<String, Id> getGLAVFromReportRow(Financial_Report_Row__c reportRow) {
        Map<String, Id> result = new Map<String, Id>();
        if (reportRow != NULL) {
            result.put('glav1', reportRow.GL_Account_Variable_1__c);
            result.put('glav2', reportRow.GL_Account_Variable_2__c);
            result.put('glav3', reportRow.GL_Account_Variable_3__c);
            result.put('glav4', reportRow.GL_Account_Variable_4__c);
        }
        return result;
    }

    private string getColumnHeaderText(String columnHeader, String columnType){
        string result = '';


        if((columnType == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD || columnType == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE)){
            Accounting_Period__c period = accountingPeriodByOffsetMap.get(columnHeader);
            if(period != null){
                switch on columnHeaderVariant {
                    when 'Accounting Period' {
                        result = columnHeader;
                    }
                    when 'Period End Date' {
                        result = period.End_Date__c.format();
                    }
                    when 'MM/YY' {
                        Datetime dtPeriodDate = datetime.newInstance(period.End_Date__c.year(), period.End_Date__c.month(), period.End_Date__c.day());
                        result = dtPeriodDate.format('MM/YYYY');
                    }
                    when else {
                        result = columnHeader;
                    }
                 }
            }else{
                result = columnHeader;
            }
        }else{
            result = columnHeader;
        }

        return result;
    }

    public Boolean getIsEndAccountingPeriodOpen() {
        Boolean retVal = false;

        Accounting_Period__c period = AccountingPeriodHandler.getInstance().getAccountingPeriodByName(endPeriodName);
        if (period != NULL && period.Status__c == AccountingPeriodActions.OPEN_STATUS) {
            retVal = true;
        }

        return retVal;
    }

    private static Map<String, Accounting_Period__c> getAccountingPeriodByOffsetMap(List<Financial_Report_Column__c> colList, String currentPeriodName) {
        Map<String, Accounting_Period__c> result = new Map<String, Accounting_Period__c>();
        AccountingPeriodHandler apHandler = AccountingPeriodHandler.getInstance();
        for (Financial_Report_Column__c col : colList) {
            if (col.Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD || col.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE) {
                Integer offset = Integer.valueOf(col.Offset__c);
                Accounting_Period__c accountingPeriod = apHandler.getAccountingPeriodByOffset(currentPeriodName, offset);
                result.put(accountingPeriod.Name, accountingPeriod );
            }
        }

        return result;
    }

    public with sharing class ReportRow {
        public String rowlabel {get; private set;}
        public String cssclass {get; private set;}
        public Integer rowIndent {get; private set;}
        public Boolean suppressPrint {get; private set;}        
        public List<ReportValue> values {get; private set;}
        
        public ReportRow() {
            values = new List<ReportValue>();
        }
    }
    

    public with sharing class ReportValue {
        public String tdClasses {get; private set;}
        public String valueClasses {get; private set;}
        public Financial_Report_Result_Value__c reportVal {get; private set;}
        public String glAccountId {get; set;}
        public String acctPeriodId {get; set;}
        public String ledgerId {get; set;}
        public Id glav1 {get; set;}
        public Id glav2 {get; set;}
        public Id glav3 {get; set;}
        public Id glav4 {get; set;}
        private Integer decimalPlaces;

        public ReportValue(
                Financial_Report_Result_Value__c reportVal,
                String glAccountId,
                String acctPeriodId,
                String ledgerId,
                Integer decimalPlaces) {
            tdClasses = '';
            valueClasses = '';
            this.glAccountId = glAccountId;
            this.acctPeriodId = acctPeriodId;
            this.reportVal = reportVal;
            this.ledgerId = populateLedgerId(ledgerId);
            this.decimalPlaces = decimalPlaces;
            this.reportVal.Text_Value__c = this.getIsCurrency() ? getFormattedDecimal() : this.reportVal.Text_Value__c;

            if (reportVal.Row_Type__c == 'Calculation %' || reportVal.Row_Type__c == 'Calculation Percentage') {
                tdClasses = 'calc';
                valueClasses = 'number pct';
            } 
            else if (reportVal.Row_Type__c == 'Calculation Number') {
                tdClasses = 'calc';
                valueClasses = 'number pct';
            } 
            else if (reportVal.Row_Type__c == 'GL Account') {
                valueClasses = 'number';
            }

            if (reportVal.Underline__c != NULL) {
                String ulType = reportVal.Underline__c;
                if (ulType == 'Single') {
                    tdClasses += ' single-ul';
                } 
                else if (ulType == 'Double') {
                    tdClasses += ' double-ul';
                }
            }
            
            if (reportVal.Currency_Value__c < 0) {
                valueClasses = valueClasses + ' neg';
            }           
        }

        public ReportValue(
                Financial_Report_Result_Value__c reportVal,
                String glAccountId,
                String acctPeriodId,
                Map<String, Id> glavMap,
                String ledgerId,
                Integer decimalPlaces) {
            this(reportVal, glAccountId, acctPeriodId, ledgerId, decimalPlaces);

            this.glav1 = glavMap.get('glav1');
            this.glav2 = glavMap.get('glav2');
            this.glav3 = glavMap.get('glav3');
            this.glav4 = glavMap.get('glav4');
        }

        public String getText() {           
            return reportVal.Text_Value__c;
        }
        
        public String getPercentageDecimal() {
            return localeFormat(reportVal.Currency_Value__c, decimalPlaces);
        }

        public String getFormattedDecimal() {
            return localeFormat(reportVal.Currency_Value__c, 2);
        }

        private String localeFormat(Decimal value, Integer scale) {
            String result = '';
            Decimal temp = value.setScale(scale);
            String fraction = String.valueOf(temp).substringAfter('.');
            result = (value < 0 ? (Decimal.valueOf(value.longValue()) - 0.1) : (Decimal.valueOf(value.longValue()) + 0.1)).format();
            result = result.substring(0, scale == 0 ? result.length() - 2 : result.length() - 1) + fraction;
            if (value < 0) {
                result = '(' + result.remove('-') + ')';
            }
            return result;
        }

        public Boolean getDisplayDetailLink() {
            return reportVal.Row_Type__c == 'GL Account' 
                        && (reportVal.Column_Type__c == 'Current Period' || reportVal.Column_Type__c == 'Year To Date')
                        && reportVal.Currency_Value__c != 0
                        && !reportVal.Suppress_Cell_Hyperlink__c;
        }
        
        public Boolean getIsCurrency() {
            
            Boolean result = false;
            
            String valType = reportVal.Column_Override_Row__c != NULL && reportVal.Column_Override_Row__c && reportVal.Row_Type__c != 'Description' && reportVal.Row_Type__c != 'Blank' ? this.reportVal.Column_Type__c : this.reportVal.Row_Type__c;
            
            if (valType == 'GL Account' || valType == 'Calculation Number'
                || valType == 'Reporting Group' || valType == 'Retained Earnings' || valType == 'Current Period') {
                result = true;
            }
            
            return result;
            
        }
        
        public Boolean getIsPercent() {
            Boolean result = false;

            if (this.reportVal.Column_Override_Row__c != null && this.reportVal.Column_Override_Row__c){
                if((this.reportVal.Column_Type__c == 'Calculation %' || this.reportVal.Column_Type__c == 'Calculation Percentage') && reportVal.Row_Type__c != 'Description' && reportVal.Row_Type__c != 'Blank'){
                    result = true;
                }
            } else if (this.reportVal.Column_Override_Row__c != null && !this.reportVal.Column_Override_Row__c){
                if(this.reportVal.Row_Type__c == 'Calculation %' || this.reportVal.Row_Type__c == 'Calculation Percentage'){
                    result = true;
                }
            }
            return result; 
        }
        
        public Boolean getIsText() {
            Boolean result = false;
            
            String valType = this.reportVal.Row_Type__c;
            
            if (valType == 'Description' || valType == 'Blank' ) {
                result = true;
            }
            
            return result;
        }

        private String populateLedgerId(Id ledgerId) {
            String result;
            if (reportVal != NULL && reportVal.Financial_Report_Column__r.Ledger__c != NULL) {
                result = reportVal.Financial_Report_Column__r.Ledger__c;
            }
            else {
                result = ledgerId;
            }
            return result;
        }
    }
}