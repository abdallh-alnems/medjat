-- MySQL dump 10.13  Distrib 8.0.44, for macos12.7 (arm64)
--
-- Host: 127.0.0.1    Database: medjat
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `expense_claims`
--

DROP TABLE IF EXISTS `expense_claims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `expense_claims` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `category` enum('travel','meals','accommodation','supplies','medical','communication','other') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'other',
  `amount` decimal(12,2) NOT NULL,
  `currency` varchar(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SAR',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `expense_date` date NOT NULL,
  `receipt_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('pending','approved','rejected','reimbursed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `rejection_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `reviewed_by` int unsigned DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_exp_tenant_status` (`tenant_id`,`status`),
  KEY `idx_exp_employee` (`employee_id`),
  KEY `reviewed_by` (`reviewed_by`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `expense_claims_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `expense_claims_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `expense_claims_ibfk_3` FOREIGN KEY (`reviewed_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `expense_claims_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `expense_claims`
--

LOCK TABLES `expense_claims` WRITE;
/*!40000 ALTER TABLE `expense_claims` DISABLE KEYS */;
INSERT INTO `expense_claims` VALUES (1,3,1,'travel',450.00,'SAR','تذاكر طيران داخلي','2026-06-02','/uploads/receipts/r1.pdf','approved',NULL,3,'2026-06-04 16:39:57',3,'2026-06-07 16:39:57'),(2,3,4,'meals',120.00,'SAR','وجبة عمل مع عميل','2026-06-03',NULL,'pending',NULL,NULL,NULL,NULL,'2026-06-07 16:39:57'),(3,3,6,'accommodation',800.00,'SAR','فندق مهمة عمل','2026-06-01','/uploads/receipts/r3.pdf','rejected','لا يوجد فاتورة أصلية',3,'2026-06-05 16:39:57',10,'2026-06-07 16:39:57'),(4,3,1,'supplies',75.00,'SAR','قرطاسية','2026-05-31',NULL,'reimbursed',NULL,3,'2026-06-06 16:39:57',3,'2026-06-07 16:39:57'),(5,3,12,'communication',200.00,'SAR','باقة إنترنت','2026-06-04',NULL,'pending',NULL,NULL,NULL,NULL,'2026-06-07 16:39:57'),(6,3,13,'medical',300.00,'SAR','علاج','2026-06-05',NULL,'approved',NULL,3,'2026-06-07 16:39:57',3,'2026-06-07 16:39:57'),(7,3,2,'other',60.00,'SAR','مصاريف متنوعة','2026-06-06',NULL,'pending',NULL,NULL,NULL,NULL,'2026-06-07 16:39:57');
/*!40000 ALTER TABLE `expense_claims` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-06-10 22:28:01
