public without sharing class EnvironmentUtils {

    public Boolean isMyDomainEnabled {
        get {
            if (isMyDomainEnabled == null) {
                isMyDomainEnabled = GlobalVariables.isMyDomainEnabled;
            }
            return isMyDomainEnabled;
        }
        set;
    }

    private String defaultLocale;
    private String defaultCurrency;
    private String datatablesLocale;

    public EnvironmentUtils() {

    }

    public EnvironmentUtils(Object obj) {

    }

    public EnvironmentUtils(ApexPages.standardController controller) {

    }

    public EnvironmentUtils(ApexPages.standardSetController controller) {

    }

    public String getDefaultLocale() {
        if (defaultLocale == NULL) {
            defaultLocale = UserInfo.getLocale().replace('_EURO', '').replaceAll('_', '-');

            if (defaultLocale == 'de-DE') {
                defaultLocale = 'de';
            }
            //=================================================================================================
        }

        return defaultLocale;
    }

    public String getDefaultCurrency() {
        if (defaultCurrency == NULL) {
            defaultCurrency = UserInfo.getDefaultCurrency();
        }

        return defaultCurrency;
    }

    // used for loading the correct jQuery DataTables internationalization plugin from static resources
    // this is necessary because 
    //      1. jQuery DataTables does not support all locales
    //      2. it is much easier than creating a file for each locale supported by SF
    public String getDatatablesLocale() {
        if (datatablesLocale == null) {
            // get user's language setting
            String language = UserInfo.getLanguage();
            // get first part of language setting (e.g. 'fr' from 'fr_CA')
            language = String.isBlank(language) || language.length() < 2 ? 'en-US' : language.toLowerCase().substring(0, 2);
            switch on language {
                when 'de' {
                    // maps all german to de-DE
                    // on frontend this maps to staticresources/internationalization_resources/javascript/datatables/de_DE.js
                    datatablesLocale = 'de-DE';
                }	
                when 'fr' {
                    // maps all french to fr-FR
                    // on frontend this maps to staticresources/internationalization_resources/javascript/datatables/fr_FR.js
                    datatablesLocale = 'fr-FR';
                }
                when else {
                    // everything else maps to en-US
                    // on frontend this maps to staticresources/internationalization_resources/javascript/datatables/en-US.js
                    datatablesLocale = 'en-US';
                }
            }
        }

        return datatablesLocale;
    }

}