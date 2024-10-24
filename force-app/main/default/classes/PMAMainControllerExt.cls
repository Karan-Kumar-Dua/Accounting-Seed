public with sharing class PMAMainControllerExt {

    public PageReference redirectToStripeSettings() {
        String redirect = ApexPages.currentPage().getParameters().get('redirect');
        if (redirect == 'false') {
            // if we are NOT comming from PaymentLink or StripeOAuthCallbackServer
            return null;
        }
        // if we are comming from PaymentLink or StripeOAuthCallbackServer
        PageReference page = new PageReference('/lightning/n/' + GlobalVariables.PACKAGE_QUALIFIER + 'Stripe_Settings');
        page.setRedirect(true);
        return page;
    }

}