// Autores:
// Tiago Demay, Lícia Sales
// Insper ---- Março de 2025


#include <iostream>
#include <fstream>
#include <vector>
#include <sstream>
#include <random>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include "hash_calculator.h"  // função sha256()

namespace fs = std::filesystem;

// === Função para ler os "Conteúdo:" das transações do arquivo ===
std::vector<std::string> readTransactionContents(const std::string& filename) {
    std::ifstream file(filename);
    std::vector<std::string> contents;
    std::string line;

    if (!file) {
        std::cerr << "❌ Erro ao abrir o arquivo " << filename << "\n";
        return contents;
    }

    while (std::getline(file, line)) {
        if (line.rfind("Conteúdo:", 0) == 0) {
            std::string content = line.substr(std::string("Conteúdo:").length());
            content.erase(0, content.find_first_not_of(" \t"));  // remove espaços
            contents.push_back(content);
        }
    }

    return contents;
}

int main(int argc, char* argv[]) {
    // === Habilita logs se variável de ambiente estiver ativa ===
    bool ENABLE_LOG = std::getenv("ENABLE_LOG_DBG") != nullptr;

    std::ofstream logFile;
    if (ENABLE_LOG) {
        fs::create_directory("logs");
        logFile.open("logs/log_miner.txt");
        if (!logFile) {
            std::cerr << "❌ Erro ao criar log.\n";
            return 1;
        }
    }

    std::string previous_hash = "0";

    // === Dificuldade via argumento ===
    std::string ref = "0000000000";  // padrão: 10 zeros
    if (argc >= 2) {
        int diff = std::stoi(argv[1]);
        if (diff >= 1 && diff <= 64)
            ref = std::string(diff, '0');
        else
            std::cerr << "⚠️ Dificuldade inválida, usando padrão: " << ref << "\n";
    }

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<unsigned int> distrib(0, UINT32_MAX);

    for (int iteration = 1; iteration <= 30; ++iteration) {
        std::string filename = "chain_sync/block" + std::to_string(iteration);
        std::vector<std::string> transactions = readTransactionContents(filename);

        if (transactions.empty()) {
            std::cerr << "⚠️ Nenhuma transação encontrada em " << filename << "\n";
            if (ENABLE_LOG) logFile << "⚠️ Nenhuma transação encontrada em " << filename << "\n";
            continue;
        }

        std::string concatenated;
        for (const auto& tx : transactions) {
            concatenated += tx;
        }

        if (ENABLE_LOG) {
            logFile << "📄 Arquivo: " << filename << "\n";
            logFile << "⛓️  Hash anterior: " << previous_hash << "\n";
            logFile << "🔗 Dados concatenados: " << concatenated << "\n";
        }

        std::string final_hash;
        unsigned int nonce = 0;
        auto start_time = std::chrono::high_resolution_clock::now();

        do {
            nonce = distrib(gen);
            std::stringstream ss;
            ss << previous_hash << concatenated << nonce;
            final_hash = sha256(ss.str());

            if (ENABLE_LOG && nonce % 100000 == 0) {
                logFile << "Tentativa " << nonce << " => " << final_hash << "\n";
            }
        } while (final_hash.substr(0, ref.size()) > ref);

        auto end_time = std::chrono::high_resolution_clock::now();
        double elapsed = std::chrono::duration<double>(end_time - start_time).count();

        std::cout << "✅ Bloco " << iteration
                  << " | Hash: " << final_hash
                  << " | Nonce: " << nonce
                  << " | Tempo: " << elapsed << "s\n";

        if (ENABLE_LOG) {
            logFile << "✅ Bloco " << iteration << " - Hash: " << final_hash
                    << " | Nonce: " << nonce
                    << " | Tempo: " << elapsed << "s\n\n";
        }

        previous_hash = final_hash;  // passa para o próximo bloco
    }

    if (ENABLE_LOG) {
        logFile.close();
    }

    return 0;
}
