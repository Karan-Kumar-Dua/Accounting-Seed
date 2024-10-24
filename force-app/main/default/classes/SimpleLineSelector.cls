/**
 * A trait for a selector that can select lines by header id.
 */
public interface SimpleLineSelector {
    /**
     * Returns a list of lines that match the given header ids.
     */
    List<SObject> selectLinesByHeaderId(Set<Id> headerIds);
    /**
     * Returns a query locator for lines that match the given header ids.
     */
    Database.QueryLocator queryLocatorByHeaderId(Set<Id> headerIds);
}