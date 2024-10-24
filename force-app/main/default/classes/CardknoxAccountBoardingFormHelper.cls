public with sharing class CardknoxAccountBoardingFormHelper {
    private class CardknoxAccountBoardingFormHelperException extends Exception{}
    @AuraEnabled(cacheable=true)
    public static AccountBoardingForm getFormData(){
        return (new AccountBoardingForm());
    }
    @AuraEnabled
    public static void submitForm(String jsonString){
        try{
            AccountBoardingForm formDetails = (AccountBoardingForm)JSON.deserialize(jsonString, AccountBoardingForm.class);
            CardknoxPartnerService.SubmitGoApp resp = CardknoxPartnerService.requestSubmitGoApp(formDetails);
            if(resp.status != 'Success'){
                throw new CardknoxAccountBoardingFormHelperException(String.join(resp.error.errorMessages, ', '));
            }
        }catch(Exception ex){
            throw new AuraHandledException(ex.getMessage());
        }
    }
    public class AccountBoardingForm{
        @AuraEnabled
        public String corporateName;
        @AuraEnabled
        public String dbaName;
        @AuraEnabled
        public String ownershipType;
        @AuraEnabled
        public Date businessStartDate;
        @AuraEnabled
        public String industryTier;
        @AuraEnabled
        public String productSold;
        @AuraEnabled
        public String businessPhone;
        @AuraEnabled
        public String taxId;
        @AuraEnabled
        public String annualCreditCardSales;
        @AuraEnabled
        public String website;
        @AuraEnabled
        public String businessEmail;
        @AuraEnabled
        public String agentName;
        @AuraEnabled
        public String agentEmail;
        @AuraEnabled
        public String routingNumber;
        @AuraEnabled
        public String accountNumber;
        @AuraEnabled
        public String bankName;
        @AuraEnabled
        public String baStreet;
        @AuraEnabled
        public String baCity;
        @AuraEnabled
        public String baState;
        @AuraEnabled
        public String baZip;
        @AuraEnabled
        public String baCountry;
        @AuraEnabled
        public String maStreet;
        @AuraEnabled
        public String maCity;
        @AuraEnabled
        public String maState;
        @AuraEnabled
        public String maZip;
        @AuraEnabled
        public String maCountry;
        @AuraEnabled
        public List<SignerInfo> signerInfo;
        @AuraEnabled
        public String token;  
        @AuraEnabled
        public String tierName;  

        public AccountBoardingForm(){}     
    }
    public class SignerInfo{
        @AuraEnabled
        public String firstName;
        @AuraEnabled
        public String lastName;
        @AuraEnabled
        public Decimal ownershipPercentage;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public Date dateOfBirth;
        @AuraEnabled
        public String ssn;
        @AuraEnabled
        public String signerStreet;
        @AuraEnabled
        public String signerCity;
        @AuraEnabled
        public String signerZip;
        @AuraEnabled
        public String signerCountry;
        @AuraEnabled
        public String signerState;
        @AuraEnabled
        public String ownerCellPhone;
    }
}