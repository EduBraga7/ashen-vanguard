# Game Design Document (GDD) - Ashen Vanguard

## 1. Visão Geral do Projeto
* **Título Oficial:** **Ashen Vanguard**
* **Gênero:** 3D Horde Survival / Bullet Heaven / Auto-Shooter (cópia fiel dos pilares de *Vampire Survivors*).
* **Perspectiva:** **Top-Down Direta (estilo Vampire Survivors)** — Câmera elevada olhando para o chão com ângulo suave, garantindo **100% de visibilidade limpa**, sem elementos de cenário cobrindo a visão do jogador, inimigos ou gemas de XP.
* **Tom & Atmosfera:** Fantasia medieval sóbria, imersiva e decadente.
* **Estilo Visual:** **Low-Poly com proporções humanas normais e anatômicas** (estilo *Valheim* / *Ashen*), sombreamento limpo, iluminação de tochas dramática e cores sóbrias.
* **Diretório do Projeto:** `C:\Users\du-xb\Documents\games\ashen-vanguard`
* **Engine:** Godot 4.7
* **Pipeline de Modelagem:** Blender 5.2 (via MCP / Python) exportando `.glb` direto para `res://assets/models/`.

---

## 2. Cenário: O Pátio do Bastião em Ruínas (*Ruined Bastion*)
Para garantir a jogabilidade idêntica ao *Vampire Survivors*:
* **Superfície Plana de Combate:** Lajes de pedra escura desgastada, com linhas de rejunte bem definidas e marcações sutis no chão.
* **Visibilidade Sem Obstrução:** Nenhuma árvore alta, teto ou pilar no centro da área de ação. Pilares e ruínas ficam nas bordas ou como obstáculos baixos colidíveis que não cobrem o campo de visão.
* **Iluminação & Clima:** Tochas com chamas ardentes nas extremidades, névoa baixa rastejando no piso e uma lua pálida projetando sombras nítidas.

---

## 3. O Herói do MVP: O Cavaleiro (*The Knight*)
* **Proporções:** Corpo humano anatômico clássico (7.5 cabeças de altura).
* **Equipamento Visual:** Armadura de placas sobre cota de malha em tons de aço e ferro escuro, ombreiras angulares, elmo com fenda de visão iluminada e capa curta.
* **Atributos Base:**
  * **Vida Máxima (HP):** 120
  * **Velocidade de Movimento:** 5.2 m/s
  * **Armadura:** 2 (reduz 2 de dano recebido)
  * **Raio de Coleta de XP (Magnet):** 2.5 metros
* **Arma Inicial:** **Espadas Espectrais (Orbit Blades)**.

---

## 4. Mecânicas Fielmente Inspiradas em *Vampire Survivors*

### 4.1 Movimentação & Auto-Ataque
* O jogador controla **exclusivamente a movimentação** (WASD / Setas / Analógico).
* Não há botão de mira nem de ataque manual. Todas as armas disparam e operam em ciclos de tempo automáticos (*cooldowns*).

### 4.2 Cristais de XP & Vácuo (Magnetismo)
* Cada inimigo derrotado deixa cair um **Cristal de XP**:
  * 🔹 **Azul Claro:** XP Básico (+1)
  * 🟢 **Verde Esmeralda:** XP Médio (+5)
  * 🔴 **Rubi Vermelho:** XP Alto (+25, deixado por inimigos mais fortes)
* Quando o herói entra no raio de coleta, o cristal voa suavemente em direção ao jogador (*efeito ímã com interpolação de aceleração*).

### 4.3 Level Up & Escolha de Upgrades
* Ao completar a barra de XP no topo da tela:
  1. O jogo **pausa imediatamente**.
  2. Surge a janela com **3 opções aleatórias** de armas novas ou melhorias para as armas já equipadas.
  3. Ao clicar na escolha, o upgrade é aplicado e o jogo retoma.

### 4.4 Números de Dano (*Floating Damage Numbers*)
* Todo golpe acertado faz subir um número de dano sobre a cabeça do monstro (amarelo para crítico, branco para normal), reforçando a sensação de impacto.

---

## 5. Armas & Itens Passivos do MVP

### Armas Ativas
| Arma | Ícone | Comportamento 3D |
| :--- | :--- | :--- |
| **Espadas Espectrais** | ⚔️ | 2 lâminas translúcidas girando ao redor do Cavaleiro em velocidade constante. Aumentar nível adiciona mais espadas e maior raio de rotação. |
| **Dardos Mágicos** | 🪄 | Disparos arcanos retos periódicos que buscam automaticamente o monstro mais próximo. |
| **Machado de Batalha** | 🪓 | Arremessado para cima, caindo em parábola e atingindo inimigos em área de impacto. |
| **Frasco de Fogo** | 🧪 | Lançado a uma distância média; cria uma poça de chamas no chão por 3 segundos. |

### Itens Passivos (Upgrades de Atributos)
* 🧲 **Amuleto de Ímã:** Aumenta o raio de atração dos cristais de XP em +30%.
* 🥾 **Botas Ágeis:** Aumenta a velocidade de movimento em +10%.
* 🛡️ **Escudo de Ferro:** Concede +1 de armadura e regenera 1 HP a cada 5 segundos.
* 🥩 **Carne Assada (Drop Raro):** Recupera 30 HP instantaneamente.

---

## 6. Ondas de Inimigos (*Wave Timeline*)
* **00:00 - 01:00:** Esqueletos lentos aparecem em pequenos grupos pelas bordas da tela.
* **01:00 - 02:30:** A densidade dobra. Surgem morcegos rápidos voando baixo.
* **03:00:** Surgimento do primeiro **Mini-Chefe** (Cavaleiro Renegado Gigante) com uma barra de vida visível. Ao morrer, dropa um Baú de Tesouro!
* **05:00:** Fim da demonstração do MVP com tela de "Vitória / Sobreviveu".
