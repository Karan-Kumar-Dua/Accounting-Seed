public with sharing class PaymentProcessorHelper {
    private static final String STRIPE_URL = 'https://connect.stripe.com/oauth/authorize';
    private static final String STRIPE_TEST_CONFIG = 'Stripe_Test_Settings';
    private static final String STRIPE_LIVE_CONFIG = 'Stripe_Settings';

    public with sharing class PaymentProcessorHelperException extends Exception{}

    /**
     * Gets the payment processor authorization url, used for connecting Accounting Seed to 
     * a payment processing service (Stripe, Cardknox).
     * 
     * @param paymentProcessorId - Id fo the payment processsor object to connect 
     *                             with external service.
     * @return the authorization url
     */
    @AuraEnabled(Cacheable=true)
    public static String getPaymentProcessorAuthorizationURL(Id paymentProcessorId) {
        try {
            // Must get session id from VF domain for Stripe OAuthCallbackServer.
            // Only VF session id will work with rest api. Lightning session id
            // is different.
            String session = getSID();
            if (String.isBlank(session)) {
                throw new PaymentProcessorHelperException(Label.ERR_PMT_CONNECT_NO_SESSION);
            }

            // only `Payment_Processor__c`s using StripeProcessorV1 supported
            Payment_Processor__c pmtProc = getPaymentProcessor(paymentProcessorId);
            if (pmtProc == null) {
                throw new PaymentProcessorHelperException(Label.ERR_PMT_CONNECT_UNSUPPORTED_PROCESSOR);
            } else {
                if (pmtProc.Type__c != PaymentProcessorActions.STRIPE_TYPE) {
                    throw new PaymentProcessorHelperException(Label.ERR_PMT_CONNECT_UNSUPPORTED_PROCESSOR);
                }
            }

            // get stripe connect test/live mode client id
            String stipeConnectClientId = getStripeConnectClientId(pmtProc);
            if (String.isBlank(stipeConnectClientId)) {
                throw new PaymentProcessorHelperException(Label.ERR_PMT_CONNECT_NO_ACCOUNT);
            }

            // build auth url
            return STRIPE_URL
                + '?response_type=code&client_id=' 
                + stipeConnectClientId 
                + '&scope=read_write&state=' 
                + session
                + '%7C' 
                + URL.getOrgDomainUrl().toExternalForm()
                + '%7C'
                + paymentProcessorId;
        }
        catch (Exception e) {
            throw new PaymentProcessorHelperException(e.getMessage());
        }
    }

    private static String getSID() {
        PageReference ref = Page.PMAMain;
        ref.getParameters().put('redirect', 'false');
        String content;
        if (Test.isRunningTest()) {
            content = '<p>test-session-id</p>';
        } else {
            content = ref.getContent().toString();
        }
        Integer start = content.indexOf('<p>') + '<p>'.length();
        Integer stop = content.indexOf('</p>');
        String sess = content.substring(start, stop);
        return String.isNotEmpty(sess) ? sess.trim() : sess;
    }

    private static Payment_Processor__c getPaymentProcessor(Id pmtProcId) {
        List<String> fields = new List<String>{
            'Id',
            'Test_Mode__c',
            'Type__c'
        };
        
        String condition = 'Id = :pmtProcId';

        SOQLBuilder q = new SOQLBuilder(Payment_Processor__c.SObjectType);
        q.assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fields)
            .setCondition(condition);

        List<Payment_Processor__c> pmtProcs = (List<Payment_Processor__c>) Database.query(q.toSOQL());
        if (pmtProcs == null || pmtProcs.isEmpty()) {
            return null;
        }
        return pmtProcs[0];
    }

    private static String getStripeConnectClientId(Payment_Processor__c pmtProc) {
        String settingsName = pmtProc.Test_Mode__c ? STRIPE_TEST_CONFIG : STRIPE_LIVE_CONFIG;
        External_Settings__mdt stripeSettings = DomainUtils.getExternalSettingsByName(settingsName);
        return stripeSettings.Value_3__c;
    }
}