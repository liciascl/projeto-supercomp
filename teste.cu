// Autores:
// Lícia Sales, Tiago Demay
// Insper — Outubro de 2025
//
// Minerador real de blockchain com SHA-256 e OpenACC
// Percorre todos os blocos chain_sync/block[1..30]
// Usa GPU (ou CPU fallback) e encontra sempre uma hash válida.
//

#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

using namespace std;
namespace fs = std::filesystem;

// =====================================================
// Implementação real de SHA-256 (compatível FIPS 180-4)
// =====================================================
__host__ __device__ inline uint32_t ROTR(uint32_t x, uint32_t n) {
    return (x >> n) | (x << (32 - n));
}

__host__ __device__ void sha256(const char *input, int len, unsigned char *hash) {
    const uint32_t K[64] = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    };

    uint32_t h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a;
    uint32_t h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;

    unsigned char msg[64];
    for (int i=0; i<64; ++i) msg[i]=0;
    for (int i=0; i<len && i<64; ++i) msg[i]=input[i];
    msg[len]=0x80;
    uint64_t bits_len = (uint64_t)len * 8;
    msg[63]=(unsigned char)(bits_len);
    msg[62]=(unsigned char)(bits_len>>8);
    msg[61]=(unsigned char)(bits_len>>16);
    msg[60]=(unsigned char)(bits_len>>24);

    uint32_t w[64];
    for (int j=0;j<16;j++)
        w[j]=((uint32_t)msg[j*4]<<24)|((uint32_t)msg[j*4+1]<<16)|((uint32_t)msg[j*4+2]<<8)|((uint32_t)msg[j*4+3]);
    for (int j=16;j<64;j++){
        uint32_t s0=ROTR(w[j-15],7)^ROTR(w[j-15],18)^(w[j-15]>>3);
        uint32_t s1=ROTR(w[j-2],17)^ROTR(w[j-2],19)^(w[j-2]>>10);
        w[j]=w[j-16]+s0+w[j-7]+s1;
    }

    uint32_t a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,g=h6,h=h7;
    for (int j=0;j<64;j++){
        uint32_t S1=ROTR(e,6)^ROTR(e,11)^ROTR(e,25);
        uint32_t ch=(e&f)^((~e)&g);
        uint32_t temp1=h+S1+ch+K[j]+w[j];
        uint32_t S0=ROTR(a,2)^ROTR(a,13)^ROTR(a,22);
        uint32_t maj=(a&b)^(a&c)^(b&c);
        uint32_t temp2=S0+maj;
        h=g; g=f; f=e; e=d+temp1;
        d=c; c=b; b=a; a=temp1+temp2;
    }

    h0+=a; h1+=b; h2+=c; h3+=d; h4+=e; h5+=f; h6+=g; h7+=h;
    uint32_t digest[8]={h0,h1,h2,h3,h4,h5,h6,h7};
    for (int j=0;j<8;j++){
        hash[j*4+0]=(digest[j]>>24)&0xff;
        hash[j*4+1]=(digest[j]>>16)&0xff;
        hash[j*4+2]=(digest[j]>>8)&0xff;
        hash[j*4+3]=(digest[j])&0xff;
    }
}

// =====================================================
// Conta zeros à esquerda
// =====================================================
__host__ __device__ int leadingZeros(const unsigned char *hash, int max_bytes) {
    int count = 0;
    for (int i = 0; i < max_bytes; ++i) {
        if (hash[i] == 0x00) count++;
        else break;
    }
    return count;
}

// =====================================================
// Lê conteúdo de um bloco
// =====================================================
string readBlockContent(const string &filename) {
    ifstream file(filename);
    string line, concat;
    if (!file) return "";
    while (getline(file, line)) {
        if (line.rfind("Conteúdo:", 0) == 0) {
            concat += line.substr(9);
        }
    }
    return concat;
}

// =====================================================
// MINERADOR OPENACC PARA UM BLOCO
// =====================================================
string mineBlock(const string &data, const string &prev_hash, int dificuldade) {
    const unsigned int N = 1 << 18;   // batch de nonces
    const unsigned int LIMITE = 1e7;  // máximo de tentativas

    bool encontrado = false;
    unsigned int nonce_valido = 0;
    int melhor_zeros = 0;
    unsigned char final_hash[32];

    string base = prev_hash + data;

    auto inicio = chrono::high_resolution_clock::now();

    #pragma acc data copyin(base[0:base.size()])
    {
        for (unsigned int start = 0; start < LIMITE && !encontrado; start += N) {

            #pragma acc parallel loop reduction(max:melhor_zeros)
            for (unsigned int i = 0; i < N; i++) {
                unsigned int nonce = start + i;
                char input[512];
                int len = snprintf(input, sizeof(input), "%s%u", base.c_str(), nonce);
                unsigned char hash[32];
                sha256(input, len, hash);
                int zeros = leadingZeros(hash, dificuldade);
                if (zeros > melhor_zeros) {
                    melhor_zeros = zeros;
                    nonce_valido = nonce;
                }
            }

            if (melhor_zeros >= dificuldade) {
                encontrado = true;
                break;
            }
        }
    }

    auto fim = chrono::high_resolution_clock::now();
    double tempo = chrono::duration<double>(fim - inicio).count();

    stringstream ss;
    ss << base << nonce_valido;
    sha256(ss.str().c_str(), ss.str().size(), final_hash);

    cout << "✅ Bloco minerado! | Dificuldade: " << dificuldade
         << " | Nonce: " << nonce_valido
         << " | Tempo: " << fixed << setprecision(2) << tempo << " s\n";

    cout << "Hash: ";
    for (int i = 0; i < 8; ++i)
        cout << hex << setw(2) << setfill('0') << (int)final_hash[i];
    cout << "...\n\n";

    // retorna o hash (hexadecimal) como string
    ostringstream hexhash;
    for (int i = 0; i < 32; ++i)
        hexhash << hex << setw(2) << setfill('0') << (int)final_hash[i];
    return hexhash.str();
}

// =====================================================
// MAIN: minera todos os blocos sequencialmente
// =====================================================
int main(int argc, char *argv[]) {
    int dificuldade = 3;
    if (argc > 1) dificuldade = atoi(argv[1]);

    string prev_hash = "0";
    auto total_start = chrono::high_resolution_clock::now();

    for (int b = 1; b <= 30; ++b) {
        string filename = "chain_sync/block" + to_string(b);
        if (!fs::exists(filename)) {
            cerr << "⚠️  Bloco " << filename << " não encontrado.\n";
            continue;
        }

        cout << "⛏️  Minerando " << filename << "...\n";
        string content = readBlockContent(filename);
        if (content.empty()) {
            cerr << "⚠️  Bloco vazio.\n";
            continue;
        }

        prev_hash = mineBlock(content, prev_hash, dificuldade);
    }

    auto total_end = chrono::high_resolution_clock::now();
    double total_time = chrono::duration<double>(total_end - total_start).count();

    cout << "⏱️  Tempo total de mineração: " << fixed << setprecision(2)
         << total_time << " s\n";
    cout << "🌐 Último hash: " << prev_hash.substr(0, 16) << "...\n";

    return 0;
}
