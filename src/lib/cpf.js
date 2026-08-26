// Utilitários de CPF: máscara de digitação e validação do dígito verificador.

export function onlyDigits(value) {
  return (value || '').replace(/\D/g, '')
}

export function formatCpf(value) {
  const digits = onlyDigits(value).slice(0, 11)
  return digits
    .replace(/(\d{3})(\d)/, '$1.$2')
    .replace(/(\d{3})(\d)/, '$1.$2')
    .replace(/(\d{3})(\d{1,2})$/, '$1-$2')
}

export function isValidCpf(value) {
  const cpf = onlyDigits(value)
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false

  let sum = 0
  for (let i = 0; i < 9; i++) sum += Number(cpf[i]) * (10 - i)
  let digit1 = (sum * 10) % 11
  if (digit1 === 10) digit1 = 0
  if (digit1 !== Number(cpf[9])) return false

  sum = 0
  for (let i = 0; i < 10; i++) sum += Number(cpf[i]) * (11 - i)
  let digit2 = (sum * 10) % 11
  if (digit2 === 10) digit2 = 0
  if (digit2 !== Number(cpf[10])) return false

  return true
}
