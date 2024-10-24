public with sharing class RemittanceComponent {
    public List<RemittanceWrapper> cRemittances {get{
        if (cRemittances != null &&
            cOffset != null && cLimit != null &&
            cRemittances.size() > cLimit
        ) {
            List<RemittanceWrapper> result = new List<RemittanceWrapper>();
            Integer rwLimit = (cOffset + cLimit < cRemittances.size()) ? (cOffset + cLimit) : cRemittances.size();
            for (Integer i = cOffset; i < rwLimit; i++) {
                result.add(cRemittances.get(i));
            }
            cRemittances = result;
            isOffsetProcessed = true;
        }
        return cRemittances;
    } set;}
    public Integer cOffset {get; set;}
    public Integer cLimit {get; set;}
    private Boolean isOffsetProcessed = false;
}