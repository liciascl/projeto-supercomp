// Autores:
// Tiago Demay, Lícia Sales
// Insper ---- Março de 2025


#include <iostream>
#include <vector>
#include <fstream>
#include <openssl/evp.h>
#include <iomanip>
#include <sstream>
#include <random>
#include <filesystem>
#include <chrono>
#include <ctime>

namespace fs = std::filesystem;

std::random_device rd;
std::mt19937 gen(rd());

// Gera string aleatória de conteúdo de transação
std::string generateTransactionContent() {
    static const char alphanum[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    std::uniform_int_distribution<> distrib(0, sizeof(alphanum) - 2);

    std::string transaction;
    for (int i = 0; i < 20; ++i) {
        transaction += alphanum[distrib(gen)];
    }
    return transaction;
}

// Gera hash SHA256 usando OpenSSL
std::string sha256(const std::string& input) {
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    const EVP_MD* md = EVP_sha256();
    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int length;

    EVP_DigestInit_ex(ctx, md, NULL);
    EVP_DigestUpdate(ctx, input.c_str(), input.size());
    EVP_DigestFinal_ex(ctx, hash, &length);
    EVP_MD_CTX_free(ctx);

    std::stringstream ss;
    for (unsigned int i = 0; i < length; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
    }
    return ss.str();
}

// Gera timestamp no formato YYYY-MM-DD HH:MM:SS
std::string currentTimestamp() {
    auto now = std::chrono::system_clock::now();
    std::time_t t_now = std::chrono::system_clock::to_time_t(now);
    std::tm* local_tm = std::localtime(&t_now);

    std::ostringstream oss;
    oss << std::put_time(local_tm, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

int main() {
    std::string outputDir = "chain_async";
    fs::create_directory(outputDir);

    std::uniform_int_distribution<> quantityDist(30, 48); // número aleatório de transações
    int globalTxId = 1;

    for (int fileIndex = 1; fileIndex <= 30; ++fileIndex) {
        int numTransactions = quantityDist(gen);

        std::string fileName = outputDir + "/block" + std::to_string(fileIndex);
        std::ofstream file(fileName);

        if (!file) {
            std::cerr << "Erro ao abrir arquivo " << fileName << std::endl;
            continue;
        }

        for (int i = 0; i < numTransactions; ++i) {
            std::string id = "tx_" + std::to_string(globalTxId++);
            std::string timestamp = currentTimestamp();
            std::string content = generateTransactionContent();
            std::string hash = sha256(content);

            file << "ID: " << id << "\n";
            file << "Timestamp: " << timestamp << "\n";
            file << "Conteúdo: " << content << "\n";
            file << "Hash: " << hash << "\n\n";
        }

        file.close();
        std::cout << "[INFO] '" << fileName << "' salvo com " << numTransactions << " transações.\n";
    }

    return 0;
}
