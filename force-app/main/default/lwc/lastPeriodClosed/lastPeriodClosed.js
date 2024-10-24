import { LightningElement, wire } from 'lwc';
import getLastClosedPeriod from '@salesforce/apex/AccountingHomeHelper.getLastClosedPeriod';
import Labels from './labels';
import {LabelService} from 'c/utils';

/**
 * Display a widget on the homepage indicating the last period closed
 * and whether there are any outstanding periods that are open and 
 * should not be.
 */
export default class LastPeriodClosed extends LightningElement {

    labels = {...LabelService, ...Labels};

    @wire (getLastClosedPeriod)
    lastPeriodClosed;

    /**
     * Display popover when title is moused over.
     */
    showPopover = false;

    /**
     * Display last period icon and name if exists.
     */
    get hasLastPeriod () {
        return this.lastPeriodClosed && this.lastPeriodClosed.data && this.lastPeriodClosed.data.period;
    }

    /**
     * Conditions for popover display: an accounting period has been
     * closed, but it's not the most recent accounting period.
     * Don't show the popover if no periods have been closed,
     * OR if the last closed period is current.
     */
    get hasLastPeriodAndIsCurrent () {
        return this.lastPeriodClosed && this.lastPeriodClosed.data &&
            this.lastPeriodClosed.data.period &&
            !this.lastPeriodClosed.data.isCurrent;
    }

    /**
     * Text is red if not current; green otherwise.
     */
    get textClass () {
        return (
            this.lastPeriodClosed && this.lastPeriodClosed.data && this.lastPeriodClosed.data.isCurrent ?
            'slds-text-color_success' :
            'slds-text-color_destructive'
        );
    }

    /**
     * Icon is red if not current; green otherwise.
     */
    get iconVariant () {
        return (
            this.lastPeriodClosed && this.lastPeriodClosed.data && this.lastPeriodClosed.data.isCurrent ?
            'success' :
            'error'
        );
    }

    /**
     * Display a flag icon if not current; checkmark icon otherwise.
     */
    get iconName () {
        return (
            this.lastPeriodClosed && this.lastPeriodClosed.data && this.lastPeriodClosed.data.isCurrent ?
            'utility:check' :
            'utility:priority'
        );
    }

    /**
     * Display the popover when the title is hovered over
     * if period closure isn't up to date.
     */
    handleOnMouseover () {
        if (this.hasLastPeriodAndIsCurrent) {
            this.showPopover = true;
        }
    }

    /**
     * Hide the popover when the title is not being hovered over
     * if the period closure isn't up to date.
     */
    handleOnMouseout () {
        if (this.hasLastPeriodAndIsCurrent) {
            this.showPopover = false;
        }
    }

}