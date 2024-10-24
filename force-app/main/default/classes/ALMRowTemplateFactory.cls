public with sharing class ALMRowTemplateFactory {
    public static ALMRowCreateHandler createTemplate(String fullyQualifiedName){
        return createInstance(fullyQualifiedName);
    }
    private static ALMRowCreateHandler createInstance(String fullyQualifiedName) {
        try {
            Type t = Type.forName(fullyQualifiedName);
            if (t == null) {
                return null;
            }
            return (ALMRowCreateHandler) t.newInstance();
        } catch (TypeException ex) {
            return null;
        }
    }
    public static ALMRowChangeHandler createRowChangeTemplate(String fullyQualifiedName){
        return createRowChangeInstance(fullyQualifiedName);
    }
    private static ALMRowChangeHandler createRowChangeInstance(String fullyQualifiedName) {
        try {
            Type t = Type.forName(fullyQualifiedName);
            if (t == null) {
                return null;
            }
            return (ALMRowChangeHandler) t.newInstance();
        } catch (TypeException ex) {
            return null;
        }
    }
}