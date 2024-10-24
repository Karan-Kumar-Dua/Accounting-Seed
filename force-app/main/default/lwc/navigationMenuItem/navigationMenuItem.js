import {api, track} from 'lwc';
import {NavigationService, NotificationService} from 'c/utils';
import {NavigationMixin} from "lightning/navigation";

export default class NavigationMenuItem extends NavigationService {
    @api menuItem;

    @track href;

    get isError() {
        return (this.menuItem.packages && !this.menuItem.valid) // don't have the required package to navigate to list view
            || !this.menuItem.accessible; // feature is not accessible for a current user
    }

    connectedCallback() {
        !this.isError && this.generateUrl();
    }

    clickHandler() {
        this.isError && this.showError(this.menuItem.error);
    }

    showError(errorMessage) {
        NotificationService.displayToastMessage(
            this,
            errorMessage,
            'Error',
            'ERROR'
        );
    }

    generateUrl() {
        const resolveCallback = url => {
            this.href = url;
        };

        switch (this.menuItem.type) {
            case 'lightningComponent':
                this.proxyNavigation(this[NavigationMixin.GenerateUrl]).navigateToLightningComponent(
                    this.menuItem.target,
                    this.menuItem.params
                ).then(resolveCallback);
                break;
            case 'object':
                this.proxyNavigation(this[NavigationMixin.GenerateUrl]).navigateToObjectHome(this.menuItem.objectApiName).then(resolveCallback);
                break;
            case 'record':
                this.proxyNavigation(this[NavigationMixin.GenerateUrl]).navigateToViewRecordPage(this.menuItem.target).then(resolveCallback);
                break;
            case 'tab':
                this.proxyNavigation(this[NavigationMixin.GenerateUrl]).navigateToCustomTab(this.menuItem.target).then(resolveCallback);
                break;
            case 'url':
                this.proxyNavigation(this[NavigationMixin.GenerateUrl]).navigateToWebPage(this.menuItem.target).then(resolveCallback);
                break;
            default:
                this.proxyNavigation(this[NavigationMixin.GenerateUrl]).navigateToPinnedListView(this.menuItem.objectApiName).then(resolveCallback);
        }
    }
}