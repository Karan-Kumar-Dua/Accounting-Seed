import { api } from "lwc";
import { NavigationService } from "c/utils";

/**
 * Surfaces a reusable slds-page-header component which supports the
 * display of knowledge base article links in the form of icons
 * along the right side of the component.
 */
export default class PageHeader extends NavigationService {

    /**
     * Page title
     */
    @api title;

    /**
     * Displayed above the title, in smaller text.
     * On a record page, this would represent the object name.
     * Displays only if breadcrumbs are not in use, as they take up
     * the same UI space.
     */
    @api subtitle;

    /**
     * Primary (left side) icon name
     */
    @api iconName;

    /**
     * Primary (left side) icon alt text for accessibility
     */
    @api iconAltText;

    /**
     * Format:
     * [
     *     {
     *          url: '',
     *          iconName: 'standard:question_feed',
     *          iconAltText: 'Knowledge Base'
     *     }
     * ]
     */
    @api knowledgeBase;

    /**
     * Displays breadcrumb navigation above the title.
     * Format:
     * [
     *      {
     *          title: 'Page Title',
     *          tab: 'customTabName'
     *      }
     * ]
     * 
     * This structure is extensible by adding a type attribute
     * and extra parameters for different page types
     * such as url, recordId
     */
    @api breadcrumbs;

    /**
     * Navigate to a different tab.
     * This method is extensible by checking for different
     * data attributes or switching on a `type` param
     * to navigate to various types of pages.
     */
    handleClick (evt) {
        let tab = evt.target.dataset.tab;
        this.navigateToCustomTab(tab);
    }
}