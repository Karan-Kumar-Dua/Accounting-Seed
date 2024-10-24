public with sharing class BDCRouterFactory {
    
    private Map<String, AbstractBDCRouter> services;

    //used by global variables to get Binding records
    public static final String BDC_TYPE_BINDING = 'AbstractBDCRouter';

    public Map<String, BDC_Binding__c> mBDCAggregationServiceRouters { get; private set; }

    public BDCRouterFactory() {
        this.services = new Map<String, AbstractBDCRouter>();
        this.mBDCAggregationServiceRouters = this.getBDCRouters();
    }

    public AbstractBDCRouter locate(String bdcRouterName) {
        String typeName = normalizeTypeName(bdcRouterName);
        if (services.containsKey(typeName)) {
            return services.get(typeName);
        }
        AbstractBDCRouter instance = this.createInstance(typeName);
        if (instance != null) {
            services.put(typeName, instance);
        }
        return instance;
    }

    private AbstractBDCRouter createInstance(String bdcRouterName) {
        try {
            BDC_Binding__c BDCBinding = this.mBDCAggregationServiceRouters.get(bdcRouterName);
            if (BDCBinding == null) {
                return null;
            }
            Type t = Type.forName(BDCBinding.To__c);
            if (t == null) {
                return null;
            }
            return (AbstractBDCRouter) t.newInstance();
        } catch (TypeException ex) {
            return null;
        }
    }

    public static String normalizeTypeName(String typeName) {
        return typeName.toLowerCase();
    }

    private Map<String, BDC_Binding__c> getBDCRouters() {
        Map<String, BDC_Binding__c> mRouters = new Map<String, BDC_Binding__c>();
        for (BDC_Binding__c binding : GlobalVariables.abstractBDCBindings) {
            mRouters.put(normalizeTypeName(binding.Name), binding);
        }
        return mRouters;
    }
}