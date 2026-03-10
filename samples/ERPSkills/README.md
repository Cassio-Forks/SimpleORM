# SimpleORM - ERP Skills Sample

Demonstracao das Skills ERP e validacao CPF/CNPJ do SimpleORM.

## Como executar

1. Abra `SimpleORMErpSkills.dpr` no Delphi
2. Compile e execute (F9)

## O que demonstra

### Validacao CPF/CNPJ (sem banco de dados)
- Validacao de CPF valido, invalido e com digitos iguais
- Validacao de CNPJ valido e invalido
- Suporte a mascara (pontos, tracos, barras)

### TSkillCalcTotal (sem banco de dados)
- Calculo automatico de total: Quantidade * Preco - Desconto
- Arredondamento para 2 casas decimais

### Skills que requerem banco de dados
- **TSkillSequence** - Numeracao sequencial via tabela de controle
- **TSkillStockMove** - Movimentacao de estoque (entrada/saida)
- **TSkillDuplicate** - Geracao de parcelas financeiras
