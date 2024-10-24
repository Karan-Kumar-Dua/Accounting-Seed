import {LightningElement} from 'lwc';
import {NavigationMixin} from 'lightning/navigation';

export default class NavigationService extends NavigationMixin(LightningElement) {
  navigation = this[NavigationMixin.Navigate];

  proxyNavigation(navigation) {
    this.navigation = navigation;
    return this;
  }

  /**
   * Open record edit modal with record page in background.
   */
  navigateToEditRecordPageWithBackgroundCtx(recordId, objectApiName) {
    const backgroundUrl = `/lightning/r/${objectApiName}/${recordId}/view`;

    return this.navigation({
      type: 'standard__recordPage',
      attributes: {
          recordId: recordId,
          objectApiName: objectApiName,
          actionName: 'edit'
      },
      state: {
          nooverride: 1,
          navigationLocation: 'DETAIL',
          backgroundContext: backgroundUrl
      }
    });
  }

  navigateToViewRecordPageByObject(recordId, objectApiName) {
    return this.navigation({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        objectApiName: objectApiName,
        actionName: 'view'
      }
    });
  }

  navigateToViewRecordPage(recordId) {
    return this.navigation({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        actionName: 'view'
      },
    });
  }

  navigateToEditRecordPage(recordId) {
    return this.navigation({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        actionName: 'edit'
      },
    });
  }

  navigateToComponent(componentName, state) {
    return this.navigation({
      type: "standard__component",
      attributes: {
        componentName: componentName
      },
      state: state
    });
  }

  navigateToObjectHome(objectApiName) {
    return this.navigation({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: objectApiName,
        actionName: 'home'
      }
    });
  }

  navigateToPinnedListView(objectApiName) {
    return this.navigation({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: objectApiName,
        actionName: 'list'
      }
    });
  }

  navigateToListView(objectApiName) {
    return this.navigation({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: objectApiName,
        actionName: 'list'
      },
      state: {
        filterName: 'Recent'
      }
    });
  }

  navigateToCustomTab(tabName) {
    return this.navigation({
      type: 'standard__navItemPage',
      attributes: {
        apiName: tabName
      }
    });
  }

  navigateToWebPage(url, replace = true) {
    return this.navigation({
      type: 'standard__webPage',
      attributes: {
        url: url
      }
    }, replace);
  }

  navigateToLightningComponent(componentName, params) {
    return this.navigation({
      type: 'standard__component',
      attributes: {
        componentName: componentName
      },
      state: params
    });
  }

  getNavigationUrl(recordId) {
    return this[NavigationMixin.GenerateUrl]({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        actionName: 'view',
      },
    })
  }

  getNavigationUrlListview(objectApiName) {
    return this[NavigationMixin.GenerateUrl]({
      type: 'standard__objectPage',
      attributes: {
          objectApiName: objectApiName,
          actionName: 'list'
      }
    })
  }
}