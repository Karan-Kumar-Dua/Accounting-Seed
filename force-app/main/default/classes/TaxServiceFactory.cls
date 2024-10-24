public with sharing class TaxServiceFactory {

    private Map<Id, TaxService.TaxSetting> taxSettingMap;

    @TestVisible
    private static final Map<String, Type> lineLevelInstance = new Map<String, Type> {
        TaxSettingsActions.NATIVE_TAX_METHOD => NativeTaxLineLevel.class,
        TaxSettingsActions.AVA_TAX_METHOD => AvaTaxLineLevel.class
    };
    @TestVisible
    private static final Map<String, Type> headerLevelInstance = new Map<String, Type> {
        TaxSettingsActions.NATIVE_TAX_METHOD => NativeTaxHeaderLevel.class,
        TaxSettingsActions.AVA_TAX_METHOD => AvaTaxHeaderLevel.class
    };

    private TaxServiceFactory() {
        taxSettingMap = TaxService.getTaxSettingMap();
    }

    private AbstractTaxService getClassInstanceByTaxSetting(Id taxSettingId) {
        if (AccountingSettingsHandler.isHeaderLevelPost()) {
            return getInstanceByMap(taxSettingId, headerLevelInstance);
        }
        return getInstanceByMap(taxSettingId, lineLevelInstance);
    }

    private AbstractTaxService getInstanceByMap(Id taxSettingId, Map<String, Type> instanceMap) {
        if (taxSettingMap.get(taxSettingId) != null && instanceMap.containsKey(taxSettingMap.get(taxSettingId).taxMethod)) {
            return (AbstractTaxService) instanceMap.get(taxSettingMap.get(taxSettingId).taxMethod).newInstance();
        }
        else {
            return null;
        }
    }

    public static Map<Id, AbstractTaxService> getTaxMethod(Set<Id> taxSettingIds) {
        Map<Id, AbstractTaxService> serviceByMethod = new Map<Id, AbstractTaxService>();
        TaxServiceFactory factory = new TaxServiceFactory();
        for (Id taxSettingId : taxSettingIds) {
            serviceByMethod.put(taxSettingId, factory.getClassInstanceByTaxSetting(taxSettingId));
        }

        return serviceByMethod;
    }
}