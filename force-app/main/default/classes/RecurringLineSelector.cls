/**
 * A trait for a selector that can select recurring lines.
 */
public interface RecurringLineSelector extends SimpleLineSelector {
    /**
     * Returns a query locator for lines that are ready to process (convert to source header and lines).
     */
    Database.QueryLocator queryLocatorByReadyToProcess();
}