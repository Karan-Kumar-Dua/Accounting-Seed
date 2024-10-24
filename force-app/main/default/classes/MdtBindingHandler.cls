/**
 * Helper for working with `Binding__mdt` data.
 * Lazyloads `Binding__mdt` records.
 */
public with sharing class MdtBindingHandler {

    // Singleton instance of this.
    // Unit tests can set System.StubProvider here to mock.
    @TestVisible
    private static MdtBindingHandler instance;
    
    // binding_type => binding_label => binding
    private Map<String,Map<String, Binding__mdt>> bindings;

    // Singleton pattern allows us to inject System.StubProvider 
    // into instance for mocking unit tests.
    public static MdtBindingHandler getInstance() {
        if (instance == null) {
            instance = new MdtBindingHandler();
        }
        return instance;
    }

    /**
     * Get a concrete instance of the Apex class associated with 
     * the `Binding_mdt` with Type and Label matching the inputs.
     */
    public Object resolve(String bindingType, String bindingLabel) {
        // lookup the binding
        Binding__mdt binding = get(bindingType, bindingLabel);
        // no binding found
        if (binding == null) {
            return null;
        }
        // determine type for create concreate instance
        Type t = getType(binding);
        // invalid type
        if (t == null) {
            return null;
        }
        // create the instance
        return t.newInstance();
    }

    /**
     * Get the `Binding__mdt` with Type and Label matching the inputs.
     */
    public Binding__mdt get(String bindingType, String bindingLabel) {
        // load all bindings of specified type
        loadBindings(bindingType);
        // check type/label binding exists
        if (bindings.containsKey(bindingType) 
                && bindings.get(bindingType).containsKey(bindingLabel)) {
            return bindings.get(bindingType).get(bindingLabel);
        }
        // not found
        return null;
    }

    /**
     * Get the `Type` of the Apex class specified by the binding.
     */
    public Type getType(Binding__mdt binding) {
        return String.isBlank(binding.Namespace__c)
            ? Type.forName(binding.To__c)
            : Type.forName(binding.Namespace__c, binding.To__c);
    }

    private void loadBindings(String bindingType) {
        if (bindings == null) {
            bindings = new Map<String,Map<String, Binding__mdt>>();
        }
        if (!bindings.containsKey(bindingType)) {
            bindings.put(bindingType, new Map<String, Binding__mdt>());
            for (Binding__mdt binding : DomainUtils.getBindingsByType(bindingType)) {
                bindings.get(bindingType).put(binding.Label, binding);
            } 
        }
    }

}