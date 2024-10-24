public with sharing class AcctSeedReportManager {

    public class InvalidColumnException extends Exception{}
    public class InvalidReportException extends Exception{}

    @TestVisible
    private static AcctSeedReportManager instance;
    public Id reportId;
    public List<Report> dbReports;
    public  Reports.ReportResults results;
    public Reports.ReportMetadata reportMetadata;
    public List<String> reportDetailColumns;
    public Map<String,Reports.DetailColumn> detailColumnToHeaderValue;
    public Reports.ReportFactWithDetails factDetails;
    public List<Reports.SummaryValue> sumValFromFactMap;
    public List<Reports.ReportDetailRow> rowsFromFactDetails;
    public List<Reports.ReportDataCell> columnOfEachRowFromRowsFromFactDetails;
    public List<String> HeaderLabels;
    //variable used to store the label and its related value of a cell from each row.
    public Map<String, Object> labelToValue = new Map<String,Object>();
    /*use this variable to extract specific columns values that you need from report and columns has their own 
      api names like auto-number field is used on report and that auto-number field column value we want to 
      extract then in that case we need to pass columnName as a "CUST_NAME" and other field name will need to
      pass as a "NameSpace__ObjectApiName.NameSPace__FieldApiNAme" in case of custom report types.
    */ 
    @TestVisible
    private List<String> columnNames;
    /**
     * this variable used to store data type of column with corrospond apex class so that user can extract data
     * from needed column based dynamic apex initiallization.
     */
    @TestVisible
    private Map<String, String> colTypeToClass = new Map<String, String>{
        'STRING_DATA' => 'AcctSeedReportDataToString',
        'CURRENCY_DATA' => 'AcctSeedReportDataToCurrency',
        'BOOLEAN_DATA' => '', //for future data parsing just we need to create respective apex class with ConsolidatedReportData interface implented
        'COMBOBOX_DATA' => '', //for future data parsing just we need to create respective apex class with ConsolidatedReportData interface implented
        'DATETIME_DATA' => '', //for future data parsing just we need to create respective apex class with ConsolidatedReportData interface implented
        'DATE_DATA' => '',     //for future data parsing just we need to create respective apex class with ConsolidatedReportData interface implented
        'DOUBLE_DATA' => '',   //for future data parsing just we need to create respective apex class with ConsolidatedReportData interface implented
        'EMAIL_DATA' => ''   //for future data parsing just we need to create respective apex class with ConsolidatedReportData interface implented
    };
    /* this variable used to store the final extracted data of different columns from all rows with additional properties like 
       currency value in case of amount column
    */
    public List<AcctSeedReportData> finalReportData;
    /**
     * This variable used to store consolidate data of report in form of one column and list of all its related data
     * and other properties like columnapi name corrospond to list of AcctSeedReportData that contains all data properties.
     */
    public Map<String, List<AcctSeedReportData>> colApiNameToReportData;
    public List<Reports.ReportFilter> filters;
    public Map<String, List<String>> filterDetails;
    public Map<String, String>  mapOfFieldNameWithAPIName;

    public static AcctSeedReportManager getInstance() {
        if (instance == NULL) {
            instance = new AcctSeedReportManager();
        }
        return instance;
    }

    public AcctSeedReportManager getReportId(List<String> reportName) {
        String format  = 'Tabular';
        List<String> queryFields = new List<String> {
            'Id',
            'DeveloperName'
        };
        String queryCondition =  'Name IN: reportName AND Format=:format';//TODO: to add folder in where clause also
        
        SOQLBuilder theQuery = new SOQLBuilder(Report.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        List<Report> reportList = (List<Report>)Database.query(theQuery.toSOQL());
        
        if(reportList.size() <= 0) {
            throw new InvalidReportException(Label.ERR_INVALID_REPORT_NAME);
         }
         
        this.dbReports = reportList;
        return this;
    }

    public AcctSeedReportManager getReportId(String reportName) {
        getReportId(new List<String>{reportName});
        this.reportId = (String) this.dbReports.get(0).get('Id');
        return this;
    }
    
    /**
     * This method gives the result of report that includes factMap , metadata and other attributes.
    */
    public AcctSeedReportManager runReportResultWithFactDetails() {
        this.results = Reports.ReportManager.runReport(this.reportId, true);
        return this;
    }

    /**
     * This method gives the result of report that includes factMap , metadata and other attributes and it is treated as 
     * similary the runReportResultWithFactDetails() works but only difference is it return Reports.ReportFactWithSummaries object
     * rather than Reports.ReportFactWithDetails object.
     */
    public AcctSeedReportManager runReportResultWithFactSummaries() {
        this.results = Reports.ReportManager.runReport(this.reportId, false);
        return this;
    }

    public AcctSeedReportManager getReportMetdata() {
        this.reportMetadata = this.results.getReportMetadata();
        return this;
    }

    public AcctSeedReportManager getReportFilters() {
        this.filters = this.reportMetadata.getReportFilters();
        return this;
    }
     
    public AcctSeedReportManager getReportFiltersDetails() {
        this.filterDetails = new Map<String, List<String>>();
        for(Reports.ReportFilter filter : this.filters){
            List<String> schemaSplit = filter.getColumn().split('\\.');
            String fieldLabel;
            String fieldType;
            if(filter.getColumn().contains('CUST_')){
                fieldLabel = mapOfFieldNameWithAPIName.get(filter.getColumn());
            }else{
                Schema.DescribeFieldResult iDFR = Schema.getGlobalDescribe().get(schemaSplit[0]).getDescribe().fields.getMap().get(schemaSplit[1]).getDescribe();
                fieldType = String.valueOf(iDFR.getType());
                fieldLabel = iDFR.getLabel();
            }
            String filterValue = (String.isNotBlank(fieldType) && (fieldType == String.ValueOf(Schema.DisplayType.CURRENCY)) && MultiCurrencyHandler.isMultiCurrencyEnabled)?((filter.getValue()).substringAfter(' ')):(filter.getValue());
            if(this.filterDetails.containsKey(fieldLabel)){
                this.filterDetails.get(fieldLabel).add(filter.getOperator() + '&FILTER_VALUE_' + filterValue);
            }else{
                List<String> lstStr = new List<String>();
                lstStr.add(filter.getOperator() + '&FILTER_VALUE_' + filterValue);
                this.filterDetails.put(fieldLabel, lstStr);
            }
        }
        return this;
    }

    public AcctSeedReportManager setReportFilters(List<ReportFilters> reptFilters,String currencyISOCodeOnPaymentProposal) {

        Map<String, List<String>> colToValue = new Map<String, List<String>>();
        //to hold exisitng filter present on LWC
        Map<String, String> colNameToOperator = new Map<String, String>();
        getReportFilters();
        
        for(ReportFilters filter : reptFilters) {
            if(colToValue.containsKey(filter.initialReportColumnName)){
                colToValue.get(filter.initialReportColumnName).add(filter.operator+'_FILTER_VAL_'+filter.value);
            }else{
                List<String> lstStr = new List<String>();
                lstStr.add(filter.operator+'_FILTER_VAL_'+filter.value);
                colToValue.put(filter.initialReportColumnName,lstStr);
            }
            
        }

        
        for(Reports.ReportFilter filter : this.filters)
        {
            List<String> schemaSplit = filter.getColumn().split('\\.');
            String fieldLabel;
            String fieldType;
            if(filter.getColumn().contains('CUST_')){
                fieldLabel = mapOfFieldNameWithAPIName.get(filter.getColumn());
            }else{
                Schema.DescribeFieldResult iDFR = Schema.getGlobalDescribe().get(schemaSplit[0]).getDescribe().fields.getMap().get(schemaSplit[1]).getDescribe();
                fieldType = String.valueOf(iDFR.getType());
                fieldLabel = iDFR.getLabel();
            }
            
            if(colToValue.containsKey(fieldLabel)){
                String val = colToValue.get(fieldLabel)[0];
                filter.setOperator(val.substringBefore('_FILTER_VAL_'));
                filter.setValue(val.substringAfter('_FILTER_VAL_'));
                if(String.IsNotBlank(currencyISOCodeOnPaymentProposal) && String.IsNotBlank(fieldType) && fieldType == String.valueOf(Schema.DisplayType.CURRENCY) && MultiCurrencyHandler.isMultiCurrencyEnabled){
                    filter.setValue(currencyISOCodeOnPaymentProposal +' '+val.substringAfter('_FILTER_VAL_'));
                }
                
                colToValue.get(fieldLabel).remove(0);

            }
        }
        this.results = Reports.ReportManager.runReport(this.reportId, this.reportMetadata, true);
        this.factDetails = (Reports.ReportFactWithDetails) this.results.getFactMap().get('T!T');
        return this;
    }

    /**
     * It will contains the Api name of Columns in Report which is not necessary that will same as api name of database field
     * like in case of custom report type auto number field api name treated as CUST_NAME and other field api name will be 
     * NameSpace__ObjectApiName.NameSPace__FieldAPiName.
    */
    public AcctSeedReportManager getReportDetailColumns() {
        this.reportDetailColumns = this.reportMetadata.getDetailColumns();
        return this;
    }

    /**
     * This method is used to store the api name of columns corrospond to its datatype, name and label
     */
    public AcctSeedReportManager getReportHeaderValue() {
        this.detailColumnToHeaderValue = new Map<String,Reports.DetailColumn>();
        
        for (String colName : this.reportDetailColumns) {
            this.detailColumnToHeaderValue.put(colName,  this.results.getReportExtendedMetadata().getDetailColumnInfo().get(colName));
        }
        return this;
    }

    /**
     * It will contains the labels of columns
    */
    public AcctSeedReportManager getReportHeaderLabels() {
       this.HeaderLabels = new List<String>();

       for(Reports.DetailColumn detailCoumn : this.detailColumnToHeaderValue.values()){
           this.HeaderLabels.add(detailCoumn.getLabel());
       } 
       return this;
    }
    
    /**
     * this method used to store the factMap details of report and using FactMap we can extract rows and columns from report
    */
    public AcctSeedReportManager getReportFactMap() {
        this.factDetails = (Reports.ReportFactWithDetails)this.results.getFactMap().get('T!T'); 
        return this;
    }

    public AcctSeedReportManager getReportSummaryValueFromResultsFactMap() {
        this.sumValFromFactMap = this.factDetails.getAggregates();
        return this;
    }
    
    /**
     * This method will store the all rows of report. 
    */
    public AcctSeedReportManager getReportRowsFromFactDetails() {
        this.rowsFromFactDetails = this.factDetails.getRows();
        if(!(this.rowsFromFactDetails.size() > 0)) {
            throw new PaymentProposal.PaymentProposalFilterException(Label.INFO_NO_RECORD_MSG);
        }
        return this;
    }
    
    /**
     * This method will store the column values of one row. 
    */
    public AcctSeedReportManager getReportColumnToEachRowsFromRowsFromFactDetails(Reports.ReportDetailRow eachRow) {
        this.columnOfEachRowFromRowsFromFactDetails = eachRow.getDataCells();
        return this;
    }

    public AcctSeedReportManager getSpecificReportColumnValue(Reports.ReportDataCell eachCell) {
        this.labelToValue.put(eachCell.getLabel(), eachCell.getValue());
        return this;
    }

    /**
     * This method will return the data type of passed column api name which is present in report
    */
    public Reports.ColumnDataType getDataTypeOfNeededColumn(String colName){
        return this.detailColumnToHeaderValue.get(colName).getDataType();
    }

    /**
     * Method used to set the columnapiname from report in columnName variable that will further used to extract data.
     */
    public AcctSeedReportManager  setNeededColumnName(List<String> columnApiNames) {
        this.columnNames = columnApiNames;
        return this;
    }

    /**
     * This method will give us data from all rows of specific columns that we passed in "columnName" variable
     */
    public AcctSeedReportManager getDataFromReport() { 
        validateColumnApiNames(this.columnNames);
        
        ConsolidatedReportData reportDataInterface;
        this.finalReportData = new List<AcctSeedReportData>();

        for(Reports.ReportDetailRow row: this.rowsFromFactDetails){
            /* this will give us list of  Reports.ReportDataCell because in one row  we can have multiple column 
               and each column of one row refer one index in above list
            */
            this.getReportColumnToEachRowsFromRowsFromFactDetails(row);
            
            for(String colName : this.columnNames){
                Integer colIndex = getIndexOfNeededColumn(colName);
                Reports.ColumnDataType colEnums = getDataTypeOfNeededColumn(colName);
                
                if(colIndex != -1){
                   /* this is used to extract the needed column from list of Reports.ReportDataCell of each row
                   */ 
                   Reports.ReportDataCell eachCell = this.columnOfEachRowFromRowsFromFactDetails[colIndex];
                   /* after extracting each column of each row parse the data present in column based on column type
                      and store in AcctSeedReportData class which will store all properties of column data in object
                   */
                   reportDataInterface = (ConsolidatedReportData) getClassInstance(this.colTypeToClass.get(colEnums.name()));
                   // setcolumn used to store the api name of column present in report of which we are extracting data
                   reportDataInterface.setColumnName(colName);
                   // setLabel used to store the value present in cloumn of each row and it will be always in string
                   reportDataInterface.setLabel(eachCell.getLabel());
                   /* convert value used to store the actual value presnt in column of each row that may vary based on type
                      of column like in case of amount value is in object format but in case of text column value is in string
                      format similarly with in case of percentage column value is present in object format with percentage column
                      value details holding and that we need to parse with corrsopond apex class and put in AcctSeedReportData.
                  */
                   finalReportData.add(reportDataInterface.convertValue(JSON.serialize(eachCell.getValue())));
                }
            }
        }

        if(this.finalReportData.size() > 0) {
           seggregateReportData();
        }

        return this;
    }

    /**
     * This method used to return consolidate data of report in form of one column and list of all its related data
     * and other properties like columnapi name corrospond to list of AcctSeedReportData that contains all data properties.
     */
    public AcctSeedReportManager seggregateReportData() {
        this.colApiNameToReportData = new Map<String, List<AcctSeedReportData>>();
        for(AcctSeedReportData repData : this.finalReportData) {
            if(this.colApiNameToReportData.containsKey(repData.columnName)) {
                this.colApiNameToReportData.get(repData.columnName).add(repData);
            }
            else{
                this.colApiNameToReportData.put(repData.columnName, new List<AcctSeedReportData>{repData});
            }
        }
        
        return this;
    }

    /**
     * this method used to validate any invalid column that user want to extract from report but does not actually
     * contains in report and each column need  always api name of column 
     */
    public AcctSeedReportManager validateColumnApiNames(List<String> columnApiNames) {
        for(String colmns : columnApiNames) {
            if(!this.reportDetailColumns.contains(colmns)) {
                    throw new InvalidColumnException(String.format(Label.ERR_INVALID_COLUMN_NAME, new List<String>{colmns}));
             }
        }
        return this;
    }

    public Integer getIndexOfNeededColumn(String colName){
        return this.reportDetailColumns.indexOf(colName);
    }

    /**
     * This method will return total number of rows present in report
     */
    public Decimal getReportTotalRecords() {
        return (Decimal) this.factDetails.getAggregates()[this.factDetails.getAggregates().size() == 0 ? 0 : this.factDetails.getAggregates().size()-1].getValue();
    }

    public Object getClassInstance(String className) {
        Type t = Type.forName(className);
        return t.newInstance();
    }

    public AcctSeedReportManager setStandardCUSTFields(Map<String, String>  mapOfFieldNameWithAPIName) {
        this.mapOfFieldNameWithAPIName = mapOfFieldNameWithAPIName; 
        return this;
    }
}