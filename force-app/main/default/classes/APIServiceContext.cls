public with sharing class APIServiceContext {

    private enum StatusCode {
        UNLICENSED_USER_ERROR,
        TRIGGER_CONTEXT_NOT_SUPPORTED,
        REST_CONTEXT_NOT_SUPPORTED,
        TEST_CONTEXT_ONLY_ERROR,
        AVATAX_CONTEXT_ONLY_ERROR
    }

    @TestVisible
    private static final String UNLICENSED_USER_ERROR = Label.COMMON_UNLICENSED_USER_ERROR;

    @TestVisible
    private static final String TRIGGER_CONTEXT_NOT_SUPPORTED_ERROR = Label.COMMON_TRIGGER_CONTEXT_NOT_SUPPORTED_ERROR;

    @TestVisible
    private static final String REST_CONTEXT_NOT_SUPPORTED_ERROR = Label.COMMON_REST_CONTEXT_NOT_SUPPORTED_ERROR;
   
    @TestVisible
    private static final String TEST_CONTEXT_ONLY_ERROR = Label.COMMON_TEST_CONTEXT_ONLY_ERROR;

    @TestVisible
    private static final String AVATAX_CONTEXT_ONLY_ERROR = Label.ERR_AVATAX_TAX_CONTEXT_ONLY;
    private static final String AUTOMATED_PROCESS_USER_NAME = 'autoproc';

    public static ServiceResult validateServiceContext(APIServiceEntry entry) {
        ServiceResult result = new ServiceResult(null,true);

        try {
            if (entry.isOnlyLicensedUserAccessible && !entry.isLicensedUser()) {
                result.errors.add(new ServiceResult.Error(StatusCode.UNLICENSED_USER_ERROR.name(), UNLICENSED_USER_ERROR));
                result.isSuccess = false;
            }
            if (entry.isOnlyTestContextAccessible && !entry.isTestContext()) {
                result.errors.add(new ServiceResult.Error(StatusCode.TEST_CONTEXT_ONLY_ERROR.name(), TEST_CONTEXT_ONLY_ERROR));
                result.isSuccess = false;
            }
            if (!entry.isTriggerContextAccessible && entry.isTriggerContext()) {
                result.errors.add(new ServiceResult.Error(StatusCode.TRIGGER_CONTEXT_NOT_SUPPORTED.name(), TRIGGER_CONTEXT_NOT_SUPPORTED_ERROR));
                result.isSuccess = false;
            }
            if (!entry.isRestContextAccessible && entry.isRestContext()) {
                result.errors.add(new ServiceResult.Error(StatusCode.REST_CONTEXT_NOT_SUPPORTED.name(), REST_CONTEXT_NOT_SUPPORTED_ERROR));
                result.isSuccess = false;
            }
            if (entry.isOnlyAvaTaxContextAccessible && !entry.isAvaTaxContext()) {
                result.errors.add(new ServiceResult.Error(StatusCode.AVATAX_CONTEXT_ONLY_ERROR.name(), AVATAX_CONTEXT_ONLY_ERROR));
                result.isSuccess = false;
            }
        }
        catch (Exception ex) {
            result = new ServiceResult(null, ex.getTypeName(), ex.getMessage());
        }
        return result;
    }

    public class APIServiceEntry {
        public Boolean isRestContextAccessible {get; set;}
        public Boolean isTriggerContextAccessible {get; set;}
        public Boolean isOnlyTestContextAccessible {get; set;}
        public Boolean isOnlyLicensedUserAccessible {get; set;}
        public Boolean isOnlyAvaTaxContextAccessible {get; set;}
        public Boolean isAvaTaxContext = false;

        public APIServiceEntry() {
            isRestContextAccessible = true;
            isTriggerContextAccessible = false;
            isOnlyTestContextAccessible = false;
            isOnlyLicensedUserAccessible = true;
            isOnlyAvaTaxContextAccessible = false;
        }

        private Boolean isAvaTaxContext() {
            return isAvaTaxContext;
        }

        private Boolean isTriggerContext() {
            return Trigger.isExecuting;
        }

        private Boolean isRestContext() {
            return RestContext.request != null;
        }

        private Boolean isTestContext() {
            return Test.isRunningTest();
        }

        private Boolean isLicensedUser() {
            Boolean retVal = true;
            if (isManagedPackagedEnvironment() && !isAutomatedProcessUser()) {
                retVal = UserInfo.isCurrentUserLicensed(GlobalVariables.PACKAGE_NAME);
            }
            return retVal;
        }

        private Boolean isManagedPackagedEnvironment() {
            Boolean retVal = true;
            try {
                Packaging.getCurrentPackageId();
            }
            catch (System.NoDataFoundException ex) {
                retVal = false;
            }

            return retVal;
        }

        private Boolean isAutomatedProcessUser() {
            return UserInfo.getUserName().startsWith(AUTOMATED_PROCESS_USER_NAME);
        }
    }
}