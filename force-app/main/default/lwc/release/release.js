import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import getPackageVersion from '@salesforce/apex/AccountingHomeHelper.getPackageVersion';
import { LabelService } from 'c/utils';
import Labels from './labels';

const RELEASE_NAME = `${LabelService.accountingHomeReleaseTitleWinter} '25`;

/**
 * Displays information about the current release,
 * including name, version number, and logo.
 */
export default class Release extends LightningElement {

    labels = Labels;
    @wire (getPackageVersion)
    packageVersion;

    /**
     * Release logo URI
     */
    releaseLogo = staticResource + '/images/winter23_release_logo.png';

    /**
     * Display a popover containing the version number
     * when this element is hovered over.
     */
    showPopover = false;

    /**
     * Only show the popover if the element is being hovered over,
     * and if there's a valid package version to display.
     * Popover is still visible to screen readers even when visually hidden.
     */
    get popoverClasses () {
        let classes = [
            'slds-popover',
            'slds-nubbin_top',
            'slds-popover_walkthrough',
            'release--popover'
        ];
        
        if (!this.showPopover) {
            classes.push('slds-hidden');
        }

        return classes.join(' ');
    }

    get releaseName() {
        return RELEASE_NAME;
    }

    get hasPackageVersion() {
        return this.packageVersion && this.packageVersion.data;
    }

    /**
     * Display the popover on hover of the release element.
     */
    handleMouseover () {
        this.showPopover = true;
    }

    /**
     * Hide the popover when the release element is not being hovered over.
     */
    handleMouseout () {
        this.showPopover = false;
    }

    /**
     * Loads IBM Plex Sans font families.
     */
    connectedCallback () {
        loadStyle(this, staticResource + '/css/accounting.css');  
    }

}