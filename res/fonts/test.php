<?php
/**
 * =====================================================
 * ΦΟΡΜΑ ΕΠΙΚΟΙΝΩΝΙΑΣ - contact.php
 * =====================================================
 * 
 * Αυτό το αρχείο λαμβάνει τα δεδομένα από τη φόρμα
 * επικοινωνίας και στέλνει email.
 * 
 * ΣΗΜΑΝΤΙΚΟ: Αλλάξτε το $to_email με το δικό σας email!
 * 
 * =====================================================
 */

// ========== ΡΥΘΜΙΣΕΙΣ EMAIL ==========
// ΕΔΩ βάζετε το email σας που θα λαμβάνει τα μηνύματα
$to_email = "info@odiamantis.gr";

// Το θέμα του email που θα λαμβάνετε
$subject_prefix = "Νέο Μήνυμα από την Ιστοσελίδα - ";


// ========== ΕΛΕΓΧΟΣ ΜΕΘΟΔΟΥ ==========
// Το αρχείο πρέπει να καλείται μόνο με POST method
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    
    // ========== ΛΗΨΗ & ΚΑΘΑΡΙΣΜΟΣ ΔΕΔΟΜΕΝΩΝ ==========
    // Παίρνουμε τα δεδομένα από τη φόρμα και τα καθαρίζουμε
    
    // Όνομα: Αφαίρεση HTML tags
    $name = strip_tags(trim($_POST["name"]));
    
    // Email: Αφαίρεση επικίνδυνων χαρακτήρων
    $email = filter_var(trim($_POST["email"]), FILTER_SANITIZE_EMAIL);
    
    // Μήνυμα: Αφαίρεση HTML tags
    $message = strip_tags(trim($_POST["message"]));
    
    
    // ========== VALIDATION - ΕΛΕΓΧΟΣ ΔΕΔΟΜΕΝΩΝ ==========
    $errors = [];
    
    // Έλεγχος: Το όνομα είναι υποχρεωτικό
    if (empty($name)) {
        $errors[] = "Το όνομα είναι υποχρεωτικό.";
    }
    
    // Έλεγχος: Το email πρέπει να είναι έγκυρο
    if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $errors[] = "Παρακαλώ εισάγετε έγκυρο email.";
    }
    
    // Έλεγχος: Το μήνυμα είναι υποχρεωτικό
    if (empty($message)) {
        $errors[] = "Το μήνυμα είναι υποχρεωτικό.";
    }
    
    
    // ========== ANTI-SPAM PROTECTION ==========
    // Honeypot: Κρυφό πεδίο που δεν πρέπει να συμπληρωθεί
    // Αν το "website" field έχει τιμή, είναι πιθανώς bot
    if (!empty($_POST["website"])) {
        http_response_code(400);
        echo "error";
        exit;
    }
    
    
    // ========== ΑΠΟΣΤΟΛΗ EMAIL ==========
    // Αν δεν υπάρχουν σφάλματα, στέλνουμε το email
    if (empty($errors)) {
        
        // Δημιουργία θέματος email
        $email_subject = $subject_prefix . $name;
        
        // Δημιουργία περιεχομένου email
        $email_body = "Έχετε λάβει νέο μήνυμα από την ιστοσελίδα.\n\n";
        $email_body .= "Όνομα: $name\n";
        $email_body .= "Email: $email\n\n";
        $email_body .= "Μήνυμα:\n$message\n";
        
        // Email Headers (από ποιον έρχεται)
        $headers = "From: $name <$email>\r\n";
        $headers .= "Reply-To: $email\r\n";
        $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
        
        // Αποστολή του email
        if (mail($to_email, $email_subject, $email_body, $headers)) {
            // ΕΠΙΤΥΧΙΑ
            http_response_code(200);
            echo "success";
            exit;
        } else {
            // ΑΠΟΤΥΧΙΑ - Πρόβλημα με τη mail() function
            http_response_code(500);
            echo "error";
            exit;
        }
        
    } else {
        // Υπάρχουν σφάλματα validation
        http_response_code(400);
        echo "error: " . implode(", ", $errors);
        exit;
    }
    
} else {
    // Το αρχείο δεν καλείται με POST method
    http_response_code(403);
    echo "Direct access not allowed";
    exit;
}
?>