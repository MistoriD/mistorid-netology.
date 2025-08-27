#!/bin/bash

# Проверка на root
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: Запускайте скрипт с sudo."
    exit 1
fi

# Проверка количества аргументов
if [[ $# -lt 2 ]]; then
    echo "Использование: $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]"
    exit 1
fi

# Аргументы
PREFIX="$1"
INTERFACE="$2"
SUBNET="$3"
HOST="$4"

# Функция: проверка октета (0–255)
valid_octet() {
    local oct="$1"
    if ! [[ "$oct" =~ ^[0-9]+$ ]] || (( oct < 0 || oct > 255 )); then
        return 1
    fi
    return 0
}

# Проверка интерфейса
if ! ip link show "$INTERFACE" &>/dev/null; then
    echo "Ошибка: интерфейс '$INTERFACE' не существует."
    exit 1
fi

# Проверка PREFIX: формат "xxx.xxx", оба октета должны быть валидными
if ! [[ "$PREFIX" =~ ^([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    echo "Ошибка: PREFIX должен быть в формате 'xxx.xxx'"
    exit 1
fi

OCT1="${BASH_REMATCH[1]}"
OCT2="${BASH_REMATCH[2]}"

if ! valid_octet "$OCT1" || ! valid_octet "$OCT2"; then
    echo "Ошибка: Октеты в PREFIX должны быть от 0 до 255"
    exit 1
fi

# Проверка SUBNET (если задан)
if [[ -n "$SUBNET" ]]; then
    if ! valid_octet "$SUBNET"; then
        echo "Ошибка: SUBNET должен быть числом от 0 до 255"
        exit 1
    fi
fi

# Проверка HOST (если задан)
if [[ -n "$HOST" ]]; then
    if ! valid_octet "$HOST"; then
        echo "Ошибка: HOST должен быть числом от 0 до 255"
        exit 1
    fi
fi

# Функция сканирования одного IP
scan() {
    local ip="$1"
    echo "Пингую: $ip"
    arping -c 3 -i "$INTERFACE" "$ip" &>/dev/null && echo "     Активен: $ip"
}

# === Логика запуска ===

if [[ -z "$SUBNET" ]]; then
    # Полное сканирование
    echo "Полное сканирование: $PREFIX.*.*"
    for s in {1..254}; do
        for h in {1..254}; do
            scan "$PREFIX.$s.$h"
        done
    done

elif [[ -z "$HOST" ]]; then
    # Подсеть
    echo "Сканирование подсети: $PREFIX.$SUBNET.*"
    for h in {1..254}; do
        scan "$PREFIX.$SUBNET.$h"
    done

else
    # Один IP
    echo "Сканирование одного IP: $PREFIX.$SUBNET.$HOST"
    scan "$PREFIX.$SUBNET.$HOST"
fi

echo "Готово."