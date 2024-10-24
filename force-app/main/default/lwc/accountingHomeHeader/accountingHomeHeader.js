import {LightningElement, track} from 'lwc';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import {MenuTreeHelper, menuTreeSource} from "./menuTreeSource";
import {loadStyle} from "lightning/platformResourceLoader";

export default class AccountingHomeHeader extends LightningElement {
    @track menuItem = menuTreeSource;

    loaded = false;
    logo = staticResource + '/images/as-logo.svg';

    connectedCallback() {
        MenuTreeHelper.fetchAHConfigurations()
            .then((result) => {
                this.acctHomeConfigurations = result;
                this.menuItem = menuTreeSource.map(mainMenuItem => ({
                    ...mainMenuItem,
                    items: mainMenuItem.items.map(menuItemsGroup => ({
                        ...menuItemsGroup,
                        items: menuItemsGroup.items.map((item) => (this.iterateToUpdateMenuItems(item)))
                    }))
                }));
            })
            .catch(() => {})
            .finally(() => {this.loaded = true});

        loadStyle(this, staticResource + '/css/accounting.css');
    }

    iterateToUpdateMenuItems(menuItem) {
        const sobjectDetails = this.acctHomeConfigurations.sobjectDetails;
        menuItem.accessible = true;
        if (menuItem.objectApiName) {
            const objectApiName = menuItem.objectApiName.toLowerCase();
            if (sobjectDetails[objectApiName] && sobjectDetails[objectApiName]['labelPlural']) {
                menuItem.label =
                    menuItem.labelPattern &&
                    menuItem.labelPattern.replace('{0}', sobjectDetails[objectApiName]['labelPlural']) ||
                    sobjectDetails[objectApiName]['labelPlural']
            }
        }

        // Template replacement on targets or objects that contain
        // a value of {*}. For objects, this is used to dynamically
        // reference package qualifiers.
        if (menuItem.target && menuItem.target.includes('{')) {
            menuItem.target = this.replaceTemplate(menuItem.target);
        }

        if (menuItem.objectApiName && menuItem.objectApiName.includes('{')) {
            menuItem.objectApiName = this.replaceTemplate(menuItem.objectApiName);
        }

        // if a menu item requires a package, check to see if that package
        // exists in the org
        if (menuItem.packages) {
            menuItem.valid = true;
            menuItem.packages.forEach((pkg) => {
                if (this.acctHomeConfigurations.packages.hasOwnProperty(pkg)) {
                    menuItem.valid = menuItem.valid && this.acctHomeConfigurations.packages[pkg];
                }
            });
        }

        if (menuItem.accessControlledByObject
                && sobjectDetails[menuItem.accessControlledByObject.objectApiName.toLowerCase()]) {

            menuItem.accessible = sobjectDetails[menuItem.accessControlledByObject.objectApiName.toLowerCase()]['accessible'];
        }

        if (menuItem.postProcessor) {
            menuItem = menuItem.postProcessor({self: {...menuItem}});
        }

        return menuItem;
    }

    /**
     * Regex replace {*} in strings with template values delivered
     * by the server. Used for e.g. package qualifiers.
     * @param {String} menuItemValue A string containing 0 or more templates: {*}
     * @returns {String} A new string with replaced template parts.
     */
    replaceTemplate(menuItemValue) {
        const templateParts = this.acctHomeConfigurations.templateParts;
        return menuItemValue.replace(
            /{(\w*)}/g,
            (m, key) => {
                return (
                    templateParts.hasOwnProperty(key) ?
                        templateParts[key] :
                        ''
                );
            }
        );
    }

    mouseleaveHandler() {
        const navigationMenu = this.template.querySelector('c-navigation-menu');
        navigationMenu && navigationMenu.hideMenuItems();
    }
}