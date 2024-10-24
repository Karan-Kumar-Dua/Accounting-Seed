public class YodleeBDCTransactionBulk extends AbstractBDCTransactionBulk {

    private static Integer maxTransactionRecordsPerCallout = 50;
    private static final Integer DEFAULT_START_DATE_OFFSET_IN_DAYS = 90;
    private static final Integer GLAM_PAGE_SIZE = 100;
    private static final Integer REFRESH_OFFSET = 14;
   
 
    public override BDCServiceResult startTransactionProcess(List<GL_Account_Mapping__c> glams) {
        BDCServiceResult serviceResult = new BDCServiceResult();
        try {
            CustomSetController glamPageController = new CustomSetController(glams);
            if (glamPageController.getResultSize() > 0) {
                //enqueue transactions download jobs page by page
                glamPageController.setPageSize(GLAM_PAGE_SIZE);
                List<GL_Account_Mapping__c> glamsPage = (List<GL_Account_Mapping__c>) glamPageController.getRecords();
                //Process first page of the GLAMs
                enqueueTransactionsDownloadJob(glamsPage);
                //Process all other pages of the GLAMs
                while (glamPageController.getHasNext()) {
                    glamPageController.next();
                    glamsPage = (List<GL_Account_Mapping__c>) glamPageController.getRecords();
                    enqueueTransactionsDownloadJob(glamsPage);
                }
            } 
        }
        catch (Exception ex) {
            throw new BDCService.BDCException(ex.getMessage());
        }

        return serviceResult;
    }

    private static void enqueueTransactionsDownloadJob(List<GL_Account_Mapping__c> glams) {
        //Extract BDCAccount Id from each GLAM (External_Id__c)
        List<String> accountIds = new List<String>();
        List<Date> allLastRefreshedDates = new List<Date>();
        for (GL_Account_Mapping__c glam : glams) {
            accountIds.add(glam.External_Id__c);
            if (glam.Last_Refreshed__c != NULL ) {
                allLastRefreshedDates.add(glam.Last_Refreshed__c.date());
            }
            else if (glam.Initial_Start_Date__c != NULL) {
                allLastRefreshedDates.add(glam.Initial_Start_Date__c);
            }
        }

        //Set data range for BDC requests
        if (allLastRefreshedDates.isEmpty()) {
            allLastRefreshedDates.add(Date.today().addDays(- DEFAULT_START_DATE_OFFSET_IN_DAYS));
        }
        allLastRefreshedDates.sort();
        //if not set directly - fromDate will be equal to most earlier date among all GLAM's Last Refreshed Date values
        Date fromDate = allLastRefreshedDates[0];
        //FS-5561 subtract the refresh offset (14 days) from the from date to give it a buffer for pulling transactions that were posted in the past
        fromDate = fromDate.addDays(REFRESH_OFFSET * -1);
        Date toDate = Date.today();
        //enqueue transactions download
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            publishTransactionsStartPlatformEvent();
            System.enqueueJob(new BankTransactionsDownloadQueueable(accountIds, 0, fromDate, toDate, maxTransactionRecordsPerCallout));
        }
    }

    public with sharing class CustomSetController {
        private List<SObject> records;
        private Map<Integer, List<SObject>> recordsToPageNumber;
        private Integer pageSize;
        private Integer currentPageNumber;

        public CustomSetController(List<SObject> records) {
            this.pageSize = 20;
            this.currentPageNumber = 1;
            this.records = records;
            paginate();
        }

        public Integer getResultSize() {
            return records.size();
        }

        public void setPageSize(Integer size) {
            if (size != NULL && size > 0) {
                this.pageSize = size;
                paginate();
            }
        }

        public List<SObject> getRecords() {
            return recordsToPageNumber.get(currentPageNumber);
        }

        public Boolean getHasNext() {
            return recordsToPageNumber.containsKey(getNextPageNumber());
        }

        public void next() {
            this.currentPageNumber = getNextPageNumber();
        }

        private Integer getNextPageNumber() {
            return currentPageNumber + 1;
        }

        private void paginate() {
            Map<Integer, List<SObject>> pages = new Map<Integer, List<SObject>>();
            Integer pageNumber = 1;
            Integer recordCount = 0;

            for (SObject rec : records) {
                recordCount++;
                if (pages.containsKey(pageNumber)) {
                    pages.get(pageNumber).add(rec);
                }
                else {
                    pages.put(pageNumber, new List<SObject>{rec});
                }
                if (recordCount == pageSize) {
                    pageNumber++;
                    recordCount = 0;
                }
            }

            this.recordsToPageNumber = pages;
        }
    }
}