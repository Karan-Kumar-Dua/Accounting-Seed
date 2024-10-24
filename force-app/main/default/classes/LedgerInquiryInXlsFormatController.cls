public with sharing class LedgerInquiryInXlsFormatController {

    private LedgerInquiryFinancialReportOptions options;
    public String xmlHeader {get; set;}
    public String dateTimeStamp {get; set;}
    public ReportWrapper theReport {get; set;}
    public ReportOptionsWrapper wrappedOptions {get; set;}

    public LedgerInquiryInXlsFormatController() {
        this.xmlHeader = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>';
        this.dateTimeStamp = getDateTimeStamp(System.now());
        try {
            this.options = getReportCriteriaOptionsFromUrl();
            this.options.reportType = FinancialReportOptions.FinancialReportType.LEDGER_INQUIRY;
            this.wrappedOptions = new ReportOptionsWrapper(this.options);
            this.theReport = new ReportWrapper(LedgerInquiryFinancialReport.runReport(this.options));
        }
        catch (Exception ex) {

        }
    }

    private LedgerInquiryFinancialReportOptions getReportCriteriaOptionsFromUrl() {
        LedgerInquiryFinancialReportOptions result;
        String base64Options = ApexPages.currentPage().getParameters().get('options');
        if (!String.isBlank(base64Options)) {
            String decodedOptions = EncodingUtil.base64Decode(base64Options).toString();
            result = (LedgerInquiryFinancialReportOptions) JSON.deserialize(
                decodedOptions, LedgerInquiryFinancialReportOptions.class
            );
        }
        return result;
    }

    private String getDateTimeStamp(Datetime now) {
        return now.month() + '-' + now.day() + '-' + now.year() + '-' + now.hour() + '-' + now.minute();
    }

    public with sharing class ReportWrapper {

        public Decimal openingBalance {get; set;}
        public Decimal currentBalance {get; set;}
        public Decimal reportAmount {get; set;}
        public Integer recordCount {get; set;}
        public String ledgerCurrency {get; set;}
        public Boolean hideOpeningBalance {get; set;}
        public Boolean hideCurrentBalance {get; set;}
        public Map<Id, FinancialReportTransactionDetail.TransactionWrapper> lines {get; set;}
  

        public ReportWrapper(LedgerInquiryFinancialReport.LedgerInquiryResponse liReportResult) {
            this.openingBalance = liReportResult.openingBalance;
            this.currentBalance = liReportResult.currentBalance;
            this.reportAmount = liReportResult.reportAmount;
            this.recordCount = liReportResult.recordCount;
            this.ledgerCurrency = liReportResult.ledgerCurrency;
            this.hideOpeningBalance = liReportResult.hideOpeningBalance;
            this.hideCurrentBalance = liReportResult.hideCurrentBalance;
            this.lines = getLinesMap(liReportResult.lines);

        }

        private Map<Id, FinancialReportTransactionDetail.TransactionWrapper> getLinesMap(List<FinancialReportTransactionDetail.TransactionWrapper> lineList
        ) {
            Map<Id, FinancialReportTransactionDetail.TransactionWrapper> result = new Map<Id, FinancialReportTransactionDetail.TransactionWrapper>();
            if (lineList != null && !lineList.isEmpty()) {
                for (FinancialReportTransactionDetail.TransactionWrapper tw : lineList) {
                    if(tw.id != NULL){
                        result.put(tw.id.id, tw);
                    }else{
                        result.put(FinancialSuiteUtils.getFakeId(Transaction__c.SObjectType), tw);
                    } 
                }
            }
            return result;
        }
    }

    public with sharing class ReportOptionsWrapper {
        public String startingAccountingPeriodName {get; set;}
        public String endingAccountingPeriodName {get; set;}
        public String ledgerName {get; set;}
        public String glAccountName {get; set;}
        public String glav1Name {get; set;}
        public String glav2Name {get; set;}
        public String glav3Name {get; set;}
        public String glav4Name {get; set;}
        public String accountName {get; set;}
        public String productName {get; set;}
        public String projectName {get; set;}
        public String projectTaskName {get; set;}
        public String sourceList {get; set;}
        public String aggregatedBy {get; set;}

        public ReportOptionsWrapper(LedgerInquiryFinancialReportOptions options) {
            this.startingAccountingPeriodName =
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(options.startingAccountingPeriod)?.Name;
            this.endingAccountingPeriodName =
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(options.endingAccountingPeriod)?.Name;
            this.ledgerName = LedgerHandler.getInstanceWithSharing().getLedgerById(options.ledger)?.Name;
            this.glAccountName =
                (!String.isBlank(options.glAccount))
                    ? DomainUtils.getGlAccountsById(new Set<Id>{options.glAccount})[0].Name : null;
            this.glav1Name =
                (!String.isBlank(options.glVariable1))
                    ? DomainUtils.getGLAVsById(new Set<Id>{options.glVariable1})[0].Name : null;
            this.glav2Name =
                (!String.isBlank(options.glVariable2))
                    ? DomainUtils.getGLAVsById(new Set<Id>{options.glVariable2})[0].Name : null;
            this.glav3Name =
                (!String.isBlank(options.glVariable3))
                    ? DomainUtils.getGLAVsById(new Set<Id>{options.glVariable3})[0].Name : null;
            this.glav4Name =
                (!String.isBlank(options.glVariable4))
                    ? DomainUtils.getGLAVsById(new Set<Id>{options.glVariable4})[0].Name : null;
            this.accountName = (!String.isBlank(options.account)) ? DomainUtils.getAccountsById(new Set<Id>{options.account})[0].Name : null;
            this.productName = (!String.isBlank(options.product)) ? DomainUtils.getProductsById(new Set<Id>{options.product})[0].Name : null;
            this.projectName = (!String.isBlank(options.project)) ? DomainUtils.getProjectsById(new Set<Id>{options.project})[0].Name: null;
            this.projectTaskName = (!String.isBlank(options.projectTask)) ? DomainUtils.getProjectTasksById(new Set<Id>{options.projectTask})[0].Name: null;
            this.sourceList = String.join(options.source, ',');
            this.aggregatedBy = options.aggregatedBy;
        }
    }

}