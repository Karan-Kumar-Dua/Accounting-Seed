public with sharing class CardknoxPartnerService {
     //cardknox Accounting board url
     public static final String ACCOUNTING_BOARD_LINK = 'https://psapi.cardknox.com/boarding/v1';

    //the xkey is required to making any callout from cardknox
    public static final String XKEY = GlobalVariables.cardknoxSettings.Value_1__c;

    /**
     * request a submit Go app
    */
    public static SubmitGoApp requestSubmitGoApp(CardknoxAccountBoardingFormHelper.AccountBoardingForm metadata) {
        String endpoint = ACCOUNTING_BOARD_LINK + '/SubmitGoApp';
        Map<String, String> headers = populateHeaderMap();

        Map<String, Object> data = new Map<String, Object>();

        data.put('apiKey',XKEY);
        data.put('tierName',metadata.industryTier);
        data.put('corporateName',metadata.corporateName);
        data.put('dbaName',metadata.dbaName);
        data.put('annualCreditCardSales',metadata.annualCreditCardSales);
        data.put('ownershipType',metadata.ownershipType);
        data.put('businessStartDate',metadata.businessStartDate);
        data.put('agentName',metadata.agentName);
        data.put('agentEmail',metadata.agentEmail);
        data.put('website',metadata.website);
        data.put('taxId',metadata.taxId);
        data.put('businessEmail',metadata.businessEmail);
        data.put('businessPhone',metadata.businessPhone);
        data.put('businessAddress',getAddress(metadata,'ba'));
        data.put('mailingAddress',getAddress(metadata,'ma'));
        data.put('productSold',metadata.productSold);
        data.put('signature',new Map<String,String>{'token'=>metadata.token});
        data.put('signerInformationList', getSignerInfo(metadata));
        data.put('bankingInformation', new Map<String,String>{
            'bankName' => metadata.bankName,
            'routingNumber' => metadata.routingNumber,
            'accountNumber' => metadata.accountNumber
        });

        HttpResponse res = HttpHandler.post(endpoint, headers, JSON.serialize(data));

        SubmitGoApp goAppresponse = (SubmitGoApp) JSON.deserialize(res.getBody(), SubmitGoApp.class);
        return goAppresponse;
    }
    private static Object[] getSignerInfo(CardknoxAccountBoardingFormHelper.AccountBoardingForm metadata){
        Object[] signerInfo = new Object[]{};
        Map<String,Object> signerDetail;
        for(CardknoxAccountBoardingFormHelper.SignerInfo info : metadata.signerInfo){
            signerDetail = new Map<String,Object>();
            signerDetail.put('ssn',info.ssn);
            signerDetail.put('dateOfBirth',info.dateOfBirth);
            signerDetail.put('firstName',info.firstName);
            signerDetail.put('lastName',info.lastName);
            signerDetail.put('address',getSignerAddress(info));
            signerDetail.put('ownershipPercentage',info.ownershipPercentage);
            signerDetail.put('title',info.title);
            signerDetail.put('ownerCellPhone',info.ownerCellPhone);
            signerInfo.add(signerDetail);
        }
        return signerInfo;
    }
    /**
     * prepare signer address from the new sub class SignerInfo
     */
    private static Map<String,Object> getSignerAddress(CardknoxAccountBoardingFormHelper.SignerInfo metadata){
        Map<String,Object> info = new Map<String,Object>();
        info.put('streetAddress', metadata.signerStreet);
        info.put('city', metadata.signerCity);
        info.put('state', metadata.signerState);
        info.put('zip', metadata.signerZip);
        info.put('country', metadata.signerCountry);
        return info;
    }
    /**
     * common adddress method to prepare addresses according to the prefix 
     */
    private static Map<String,Object> getAddress(CardknoxAccountBoardingFormHelper.AccountBoardingForm metadata,String prefix){
        Map<String,Object> info = new Map<String,Object>();
        info.put('streetAddress',prefix == 'ba' ? metadata.baStreet : metadata.maStreet);
        info.put('city',prefix == 'ba' ? metadata.baCity : metadata.maCity);
        info.put('state',prefix == 'ba' ? metadata.baState : metadata.maState);
        info.put('zip',prefix == 'ba' ? metadata.baZip : metadata.maZip);
        info.put('country',prefix == 'ba' ? metadata.baCountry : metadata.maCountry);
        return info;
    }
    private static Map<String, String> populateHeaderMap() {
        Map<String, String> headers = new Map<String, String>();
        headers.put('Content-Type', 'application/json');
        return headers;
    }
    public with sharing class TiersData {
        public String refnum;
        public List<String> tiers;
        public ErrorData error;
        public String status;
    }
    public with sharing class SubmitGoApp {
        public String appId;
        public String refnum;
        public String status;
        public ErrorData error;
    }
    public with sharing class ErrorData {
        public String errorCode;
        public List<String> errorMessages;
    }
}