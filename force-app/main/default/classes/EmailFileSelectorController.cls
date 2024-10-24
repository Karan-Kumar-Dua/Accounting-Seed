public with sharing class EmailFileSelectorController {
   
    public static final Integer FILE_QUANTITY_LIMIT = 5;
    public static final Integer FILE_SIZE_LIMIT = 10485760;
    public static final String FILE_QUANTITY_LIMIT_ERROR_MESSAGE = Label.ERR_FILE_QUANTITY_LIMIT;
    public static final String NEW_FILE_SIZE_LIMIT_ERROR_MESSAGE = Label.ERR_NEW_FILE_SIZE_LIMIT;
    public static final String TOTAL_ATTACHMENTS_QUANTITY_LIMIT_ERROR_MESSAGE = Label.ERR_EMAIL_TOTAL_ATTACHMENTS_QUANTITY_LIMIT;
    public static final String TOTAL_FILES_SIZE_LIMIT_ERROR_MESSAGE = Label.ERR_EMAIL_TOTAL_FILES_SIZE_LIMIT;

    private String entityId;
    private Integer totalSizeOfAttachments;
    private Integer totalQuantityOfAttachments;

    public List<SelectOption> fileLocationOptions {get; private set;}
    public String selectedFileLocation {get; set;}
    public List<ContentVersion> sfFiles {get; private set;}
    public List<AbstractStatementManager.CustomEmailAttachment> newFiles {get; private set;}
    public String serializedNewFiles {get; set;}
    public ContentVersion stubFile {get; set;}
    public Boolean isFileSizeLimitExceeded {get; set;}
    public String fileSizeLimitErrorMessage {get; set;}
    public String statementMode {get; set;}

    public EmailFileSelectorController() {
        this.entityId = ApexPages.currentPage().getParameters().get('entityId');
        this.statementMode = ApexPages.currentPage().getParameters().get('stmMode');
        this.isFileSizeLimitExceeded = false;
        this.totalSizeOfAttachments = 0;
        this.totalQuantityOfAttachments = 0;
        this.selectedFileLocation = 'local';
        this.sfFiles = new List<ContentVersion>();
        this.newFiles = new List<AbstractStatementManager.CustomEmailAttachment>();
        this.stubFile = new ContentVersion();
        getFileLocationSelectOptions();
    }

    private void getFileLocationSelectOptions() {
        fileLocationOptions = new List<SelectOption>();
        fileLocationOptions.add(new SelectOption('local', 'My Computer'));
        fileLocationOptions.add(new SelectOption('entity', (statementMode == 'billing') ? 'Billing Files' : 'Account Files'));
    }

    public PageReference queryFiles() {
        sfFiles = DomainUtils.getFilesByLinkedEntityId(entityId);
        return NULL;
    }

    public PageReference attach() {
        this.isFileSizeLimitExceeded = false;
        this.fileSizeLimitErrorMessage = '';
        if (stubFile.VersionData != NULL && stubFile.Title != NULL) {
            try {
                if (stubFile.ContentSize > FILE_SIZE_LIMIT) {
                    isFileSizeLimitExceeded = true;
                    fileSizeLimitErrorMessage = NEW_FILE_SIZE_LIMIT_ERROR_MESSAGE;
                    return NULL;
                }
                if (stubFile.ContentSize + totalSizeOfAttachments > FILE_SIZE_LIMIT) {
                    isFileSizeLimitExceeded = true;
                    fileSizeLimitErrorMessage = TOTAL_FILES_SIZE_LIMIT_ERROR_MESSAGE;
                    return NULL;
                }

                totalQuantityOfAttachments++;
                if (totalQuantityOfAttachments > FILE_QUANTITY_LIMIT) {
                    isFileSizeLimitExceeded = true;
                    fileSizeLimitErrorMessage = FILE_QUANTITY_LIMIT_ERROR_MESSAGE;
                    return NULL;
                }

                totalSizeOfAttachments += stubFile.ContentSize;

                stubFile.PathOnClient = stubFile.Title;
                SFDCSecurityUtils.insertProxy(stubFile);

                AbstractStatementManager.CustomEmailAttachment nf = new AbstractStatementManager.CustomEmailAttachment();
                nf.fileId = stubFile.Id;
                nf.fileName = stubFile.Title;
                nf.fileSize = stubFile.ContentSize;
                nf.isLinkedWithEntity = false;
                newFiles.add(nf);
                serializedNewFiles = JSON.serialize(newFiles);
            }
            catch (Exception ex) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
                return NULL;
            }
            finally {
                this.stubFile = new ContentVersion();
            }
        }
        return NULL;
    }

    public Boolean getShowAttachments() {
        return !newFiles.isEmpty();
    }

}