global with sharing class APDisbursementPostService {

    global static List<PostResult> postApDisbursements(List<AP_Disbursement__c> apDisbursements) {
        AbstractPostHandler postHandler = new APDisbursementPostHandler();
        return postHandler.post(apDisbursements);
    }

}