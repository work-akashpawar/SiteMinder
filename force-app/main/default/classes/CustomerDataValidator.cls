/**
 * Name       : Akash Pawar
 * Description: Helper class for validating and normalizing Customer data
 * Provides methods for name normalization and email validation
 */
public with sharing class CustomerDataValidator {
    
    // Email validation regex pattern
    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'
    );
    
    /**
     * Validation result wrapper class
     */
    public class ValidationResult {
        public Boolean isValid { get; set; }
        public String errorMessage { get; set; }
        public Customer__c normalizedCustomer { get; set; }
        
        public ValidationResult() {
            this.isValid = true;
            this.errorMessage = '';
        }
    }
    
    /**
     * Validates and normalizes a single customer record
     * @param customer The customer record to validate
     * @return ValidationResult containing validation status and normalized data
     */
    public static ValidationResult validateAndNormalize(Customer__c customer) {
        ValidationResult result = new ValidationResult();
        result.normalizedCustomer = customer.clone(true, true, true, true);
        
        try {
            // Normalize names
            if (String.isNotBlank(customer.First_Name__c)) {
                result.normalizedCustomer.First_Name__c = normalizeName(customer.First_Name__c);
            }
            
            if (String.isNotBlank(customer.Last_Name__c)) {
                result.normalizedCustomer.Last_Name__c = normalizeName(customer.Last_Name__c);
            } else {
                result.isValid = false;
                result.errorMessage = 'Last Name is required';
                return result;
            }
            
            // Validate email if provided
            if (String.isNotBlank(customer.Email__c)) {
                if (!isValidEmail(customer.Email__c)) {
                    result.isValid = false;
                    result.errorMessage = 'Invalid email format: ' + customer.Email__c;
                    return result;
                } else {
                    // Normalize email to lowercase
                    result.normalizedCustomer.Email__c = customer.Email__c.toLowerCase().trim();
                }
            }
            
        } catch (Exception e) {
            result.isValid = false;
            result.errorMessage = 'Validation error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Normalizes a name by proper casing and trimming
     * Examples: "john doe" -> "John Doe", "  JANE  " -> "Jane"
     * @param name The name to normalize
     * @return Normalized name
     */
    public static String normalizeName(String name) {
        if (String.isBlank(name)) {
            return name;
        }
        
        // Trim and convert to lowercase
        String normalized = name.trim().toLowerCase();
        
        // Split by spaces and capitalize each word
        List<String> words = normalized.split('\\s+');
        List<String> capitalizedWords = new List<String>();
        
        for (String word : words) {
            if (String.isNotBlank(word)) {
                capitalizedWords.add(word.capitalize());
            }
        }
        
        return String.join(capitalizedWords, ' ');
    }
    
    /**
     * Validates email format using regex
     * @param email The email to validate
     * @return True if email is valid, false otherwise
     */
    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        
        String trimmedEmail = email.trim();
        Matcher matcher = EMAIL_PATTERN.matcher(trimmedEmail);
        return matcher.matches();
    }
    
    /**
     * Batch validates multiple customer records
     * @param customers List of customers to validate
     * @return Map of customer Id to validation result
     */
    public static Map<Id, ValidationResult> validateBatch(List<Customer__c> customers) {
        Map<Id, ValidationResult> results = new Map<Id, ValidationResult>();
        
        for (Customer__c customer : customers) {
            ValidationResult result = validateAndNormalize(customer);
            results.put(customer.Id, result);
        }
        
        return results;
    }
}


// Process
CustomerBatchProcessor batch = new CustomerBatchProcessor(
    'Pending',  // Status filter
    'work.akashpawar@gmail.com'  // Notification email
);