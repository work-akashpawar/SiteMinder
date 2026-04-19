public with sharing class AccountDashboardController {
    
    /**
     * Retrieves Account data along with related Contacts and Opportunities
     * @param accountId The Id of the Account to query
     * @return AccountDataWrapper containing account name, contacts, and opportunities
     */
    @AuraEnabled(cacheable=true)
    public static AccountDataWrapper getAccountData(Id accountId) {
        AccountDataWrapper wrapper = new AccountDataWrapper();
        
        try {
            // Validate accountId
            if (accountId == null) {
                throw new AuraHandledException('Account Id is required');
            }
            
            // Query Account with related Contacts and Opportunities
            Account acc = [
                SELECT Id, Name,
                    (SELECT Id, Name, Email, Phone, Title 
                     FROM Contacts 
                     ORDER BY Name ASC),
                    (SELECT Id, Name, StageName, Amount, CloseDate 
                     FROM Opportunities 
                     ORDER BY CloseDate DESC)
                FROM Account 
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            // Populate wrapper
            wrapper.accountName = acc.Name;
            wrapper.contacts = acc.Contacts;
            wrapper.opportunities = acc.Opportunities;
            
        } catch (QueryException qe) {
            throw new AuraHandledException('Error querying account data: ' + qe.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
        
        return wrapper;
    }
    
    /**
     * Wrapper class to return structured data to the component
     */
    public class AccountDataWrapper {
        @AuraEnabled
        public String accountName { get; set; }
        
        @AuraEnabled
        public List<Contact> contacts { get; set; }
        
        @AuraEnabled
        public List<Opportunity> opportunities { get; set; }
        
        public AccountDataWrapper() {
            this.contacts = new List<Contact>();
            this.opportunities = new List<Opportunity>();
        }
    }
}