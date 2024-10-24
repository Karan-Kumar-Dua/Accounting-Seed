public with sharing class AmortizationMethodFactory {

    private static final Type DEFAULT_AMORTIZATION_METHOD = DailyAmortization.class;
    private Map<String, AbstractAmortization> services;

    public static final String AMORTIZATION_TYPE_BINDING = 'AbstractAmortization';
    public Map<String, Binding__mdt> mAmortizationMethodTypes { get; private set; }

    public AmortizationMethodFactory() {
        this.services = new Map<String, AbstractAmortization>();
        this.mAmortizationMethodTypes = this.getAmortizationMethods();
    }

    public AbstractAmortization locate(String amortizationMethodName) {
        String t = normalizeTypeName(amortizationMethodName);
        if (services.containsKey(t)) {
            return services.get(t);
        }
        AbstractAmortization instance = this.createInstance(t);
        if (instance != null) {
            services.put(t, instance);
        }
        return instance;
    }

    private AbstractAmortization createInstance(String amortizationMethodName) {
        try {
            Binding__mdt amortizationBinding = this.mAmortizationMethodTypes.get(amortizationMethodName);
            if (amortizationBinding == null) {
                return null;
            }
            Type t = String.isBlank(amortizationBinding.Namespace__c)
                    ? Type.forName(amortizationBinding.To__c)
                    : Type.forName(amortizationBinding.Namespace__c, amortizationBinding.To__c);
            if (t == null) {
                return null;
            }
            return (AbstractAmortization) t.newInstance();
        } catch (TypeException ex) {
            return null;
        }
    }

    public static String normalizeTypeName(String s) {
        String t = String.isBlank(s) ? DEFAULT_AMORTIZATION_METHOD.toString() : s;
        return t.toLowerCase();
    }

    private Map<String, Binding__mdt> getAmortizationMethods() {
        Map<String, Binding__mdt> mMethods = new Map<String, Binding__mdt>();
        for (Binding__mdt binding : GlobalVariables.abstractAmortizationBindings) {
            mMethods.put(normalizeTypeName(binding.Label), binding);
        }
        return mMethods;
    }
}